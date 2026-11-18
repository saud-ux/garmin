import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Math;
import Toybox.Attention;

// Phases
// "1st"  first half running
// "half" break (counts up)
// "2nd"  second half running
// "done" match finished
class Match {

    var id;                 // Firestore document id (String)
    var homeName, homeColor;
    var awayName, awayColor;
    var halfLen, brkLen;    // minutes
    var kickoff;            // "home" | "away"
    var isNew;              // true = created on watch (needs full create push)

    var phase;              // see above
    var elapsedSec;         // main clock seconds
    var running;            // main clock running
    var added1, added2;     // added minutes per half

    var addedTargetSec;     // target of secondary added counter (sec)
    var addedElapsedSec;    // elapsed of secondary added counter (sec)
    var addedRunning;       // secondary counter active

    var breakSec;           // break counter seconds
    var events;             // Array of event Dictionaries

    var timer;
    var _tick;              // counts seconds for throttled cloud push

    function initialize(cfg) {
        id        = cfg.hasKey("id")        ? cfg["id"]        : newId();
        homeName  = cfg.hasKey("homeName")  ? cfg["homeName"]  : "الأرض";
        homeColor = cfg.hasKey("homeColor") ? cfg["homeColor"] : "green";
        awayName  = cfg.hasKey("awayName")  ? cfg["awayName"]  : "الضيف";
        awayColor = cfg.hasKey("awayColor") ? cfg["awayColor"] : "blue";
        halfLen   = cfg.hasKey("halfLen")   ? cfg["halfLen"]   : 45;
        brkLen    = cfg.hasKey("brkLen")    ? cfg["brkLen"]    : 15;
        kickoff   = cfg.hasKey("kickoff")   ? cfg["kickoff"]   : "home";
        isNew     = cfg.hasKey("isNew")     ? cfg["isNew"]     : true;

        phase          = "1st";
        elapsedSec     = 0;
        running        = false;
        added1         = 0;
        added2         = 0;
        addedTargetSec = 0;
        addedElapsedSec= 0;
        addedRunning   = false;
        breakSec       = 0;
        events         = [];
        _tick          = 0;
    }

    function newId() {
        var t = Time.now().value();
        var r = (Math.rand() % 100000);
        return t.toString() + r.toString();
    }

    // ---- timer ----
    function startTimer() {
        if (timer == null) {
            timer = new Timer.Timer();
            timer.start(method(:onTick), 1000, true);
        }
    }

    function stopTimer() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
    }

    function onTick() as Void {
        if ((phase.equals("1st") || phase.equals("2nd")) && running) {
            elapsedSec += 1;
            if (addedRunning) {
                addedElapsedSec += 1;
                if (addedElapsedSec == addedTargetSec) {
                    buzz(2);   // added time fully elapsed
                }
            }
        } else if (phase.equals("half")) {
            breakSec += 1;
        }
        _tick += 1;
        if (_tick % 5 == 0) {
            pushLive();   // throttle cloud writes to every 5s
        }
        if (_tick % 30 == 0) {
            persist();    // local snapshot every 30s (clock catches up on resume)
        }
        if (_tick % 60 == 0 && gSync != null && gSync.pending() > 0) {
            gSync.flush();   // phone came back — drain what is waiting
        }
        WatchUi.requestUpdate();
    }

    // ---- phase control ----
    function start() {
        phase = "1st";
        elapsedSec = 0;
        running = true;
        startTimer();
        if (isNew && gSync != null) {
            gSync.pushFull(self);   // create full doc for watch-made match
            isNew = false;
        } else {
            pushNow();
        }
        persist();
    }

    function endFirstHalf() {
        phase = "half";
        running = false;
        addedRunning = false;
        breakSec = 0;
        buzz(2);
        persist();
        pushNow();
    }

    function startSecondHalf() {
        phase = "2nd";
        elapsedSec = halfLen * 60;
        running = true;
        addedRunning = false;
        addedElapsedSec = 0;
        addedTargetSec = 0;
        persist();
        pushNow();
    }

    function endMatch() {
        phase = "done";
        running = false;
        addedRunning = false;
        buzz(3);
        persist();
        pushNow();
    }

    // ---- added time ----
    function setAddedTime(minutes) {
        if (phase.equals("1st")) { added1 = minutes; }
        else if (phase.equals("2nd")) { added2 = minutes; }
        addedTargetSec = minutes * 60;
        addedElapsedSec = 0;
        addedRunning = minutes > 0;
        persist();
        pushNow();
    }

    // ---- events ----
    // Returns true if a second-yellow red was auto-added.
    function addEvent(kind, team, player, note) {
        var min = currentMinute();
        var ev = {
            "id"     => newId(),
            "kind"   => kind,
            "min"    => min,
            "team"   => team,
            "player" => (player == null ? "" : player),
            "note"   => (note == null ? "" : note)
        };
        events.add(ev);

        var second = false;
        if (kind.equals("yellow") && player != null && !player.equals("")) {
            if (hasYellow(team, player)) {
                events.add({
                    "id"     => newId(),
                    "kind"   => "red",
                    "min"    => min,
                    "team"   => team,
                    "player" => player,
                    "note"   => "",
                    "second" => true
                });
                second = true;
            }
        }
        buzz(1);
        persist();
        pushNow();
        return second;
    }

    function hasYellow(team, player) {
        for (var i = 0; i < events.size(); i++) {
            var e = events[i];
            if (e["kind"].equals("yellow") && e["team"].equals(team) &&
                e["player"] != null && e["player"].equals(player)) {
                // exclude the one we just added (last element)
                if (i < events.size() - 1) { return true; }
            }
        }
        return false;
    }

    function undoLast() {
        if (events.size() > 0) {
            var last = events[events.size() - 1];
            events.remove(last);
            // if the removed one was an auto second-yellow red, also drop the yellow
            if (last.hasKey("second") && last["second"] && events.size() > 0) {
                var prev = events[events.size() - 1];
                if (prev["kind"].equals("yellow") && prev["min"] == last["min"] &&
                    prev["team"].equals(last["team"])) {
                    events.remove(prev);
                }
            }
            persist();
            pushNow();
        }
    }

    // ---- derived ----
    function score() {
        var h = 0; var a = 0;
        for (var i = 0; i < events.size(); i++) {
            if (events[i]["kind"].equals("goal")) {
                if (events[i]["team"].equals("home")) { h += 1; } else { a += 1; }
            }
        }
        return [h, a];
    }

    function count(kind) {
        var n = 0;
        for (var i = 0; i < events.size(); i++) {
            if (events[i]["kind"].equals(kind)) { n += 1; }
        }
        return n;
    }

    function currentMinute() {
        var m = (elapsedSec / 60) + 1;
        return m;
    }

    function clockText() {
        return mmss(elapsedSec);
    }

    function breakText() {
        return mmss(breakSec);
    }

    function addedText() {
        return "+" + mmss(addedElapsedSec) + " / +" + mmss(addedTargetSec);
    }

    function teamName(team) {
        return team.equals("home") ? homeName : awayName;
    }

    function pushLive() {
        if (gSync != null) {
            gSync.pushLive(self);
        }
    }

    function pushNow() {
        if (gSync != null) {
            gSync.pushNow(self);
        }
    }

    // ---- local persistence ----
    function toDict() {
        return {
            "id"              => id,
            "homeName"        => homeName,
            "homeColor"       => homeColor,
            "awayName"        => awayName,
            "awayColor"       => awayColor,
            "halfLen"         => halfLen,
            "brkLen"          => brkLen,
            "kickoff"         => kickoff,
            "isNew"           => isNew,
            "phase"           => phase,
            "elapsedSec"      => elapsedSec,
            "running"         => running,
            "added1"          => added1,
            "added2"          => added2,
            "addedTargetSec"  => addedTargetSec,
            "addedElapsedSec" => addedElapsedSec,
            "addedRunning"    => addedRunning,
            "breakSec"        => breakSec,
            "events"          => events,
            "savedAt"         => Time.now().value()
        };
    }

    function persist() {
        Store.saveActive(toDict());
    }

    static function dg(d, k, def) {
        if (d != null && d.hasKey(k) && d[k] != null) { return d[k]; }
        return def;
    }

    // Rebuild a match from its stored snapshot and catch the clock up to now.
    static function fromDict(d) {
        if (d == null) { return null; }
        var m = new Match({
            "id"        => dg(d, "id", null),
            "homeName"  => dg(d, "homeName", "الأرض"),
            "homeColor" => dg(d, "homeColor", "green"),
            "awayName"  => dg(d, "awayName", "الضيف"),
            "awayColor" => dg(d, "awayColor", "blue"),
            "halfLen"   => dg(d, "halfLen", 45),
            "brkLen"    => dg(d, "brkLen", 15),
            "kickoff"   => dg(d, "kickoff", "home"),
            "isNew"     => dg(d, "isNew", false)
        });
        m.phase           = dg(d, "phase", "1st");
        m.elapsedSec      = dg(d, "elapsedSec", 0);
        m.running         = dg(d, "running", false);
        m.added1          = dg(d, "added1", 0);
        m.added2          = dg(d, "added2", 0);
        m.addedTargetSec  = dg(d, "addedTargetSec", 0);
        m.addedElapsedSec = dg(d, "addedElapsedSec", 0);
        m.addedRunning    = dg(d, "addedRunning", false);
        m.breakSec        = dg(d, "breakSec", 0);
        var ev = dg(d, "events", []);
        m.events = (ev instanceof Lang.Array) ? ev : [];

        var gap = Time.now().value() - dg(d, "savedAt", Time.now().value());
        if (gap > 0) {
            if ((m.phase.equals("1st") || m.phase.equals("2nd")) && m.running) {
                m.elapsedSec += gap;
                if (m.addedRunning) { m.addedElapsedSec += gap; }
            } else if (m.phase.equals("half")) {
                m.breakSec += gap;
            }
        }
        return m;
    }

    static function mmss(s) {
        var m = s / 60;
        var r = s % 60;
        var rr = r < 10 ? "0" + r.toString() : r.toString();
        return m.toString() + ":" + rr;
    }

    static function buzz(n) {
        if (Toybox has :Attention) {
            if (Attention has :vibrate) {
                var profile = [];
                for (var i = 0; i < n; i++) {
                    profile.add(new Attention.VibeProfile(50, 200));
                    profile.add(new Attention.VibeProfile(0, 120));
                }
                Attention.vibrate(profile);
            }
        }
    }
}
