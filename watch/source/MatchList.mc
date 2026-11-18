import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;

// Launch screen. Shows the saved match list straight away, refreshes it from
// the website when the phone is reachable, and never ends up empty just
// because the connection dropped. Never auto-selects — the ref always picks.
class MatchListView extends WatchUi.View {

    var _shown;     // a list has already been put on screen
    var _timer;     // fallback timer: don't wait forever for the website
    var _cached;    // last known list from storage

    function initialize() {
        View.initialize();
        _shown = false;
    }

    function onShow() as Void {
        _cached = Store.loadList();
        var wait = 80;              // offline: show the saved list at once
        if (gSync != null) {
            gSync.flush();          // send anything that is still waiting
            if (gSync.online()) {
                wait = 2500;        // online: give the website a moment
                gSync.fetchMatches(method(:onMatches));
            }
        }
        _timer = new Timer.Timer();
        _timer.start(method(:onTimeout), wait, false);
    }

    function onHide() as Void {
        stopTimer();
    }

    function stopTimer() {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimeout() as Void {
        _timer = null;
        showList(_cached);          // website too slow — use what we have
    }

    function onMatches(list) as Void {
        if (list == null) {         // could not reach the website
            showList(_cached);
            return;
        }
        Store.saveList(list);       // keep it for the next time we are offline
        showList(list);
    }

    function showList(list) as Void {
        if (_shown) { return; }
        _shown = true;
        stopTimer();
        if (list == null) { list = []; }

        var upcoming = [];
        for (var i = 0; i < list.size(); i++) {
            var st = list[i]["status"];
            if (st == null || st.equals("upcoming")) {
                upcoming.add(list[i]);
            }
        }

        var menu = new WatchUi.Menu2({ :title => "المباريات" });

        var act = Store.loadActive();
        var hasResume = false;
        if (act != null && !Match.dg(act, "phase", "done").equals("done")) {
            hasResume = true;
            menu.addItem(new WatchUi.MenuItem("استكمال المباراة",
                Match.dg(act, "homeName", "") + " · " + Match.dg(act, "awayName", ""),
                "__resume__", null));
        }

        menu.addItem(new WatchUi.MenuItem("مباراة جديدة", null, "__new__", null));

        for (var i = 0; i < upcoming.size(); i++) {
            var m = upcoming[i];
            var title = m["homeName"] + " · " + m["awayName"];
            menu.addItem(new WatchUi.MenuItem(title, fmtWhen(m["date"]), i.toString(), null));
        }

        menu.addItem(new WatchUi.MenuItem("مزامنة الآن", statusLine(), "__sync__", null));
        WatchUi.switchToView(menu, new MatchMenuDelegate(upcoming, hasResume), WatchUi.SLIDE_LEFT);
    }

    // "غير متصل · آخر تحديث قبل 3 س · بانتظار الرفع 2"
    function statusLine() {
        var s = "";
        if (gSync != null && !gSync.online()) {
            s = "غير متصل";
        }
        var ls = Store.lastSyncText();
        if (ls != null) {
            s = s.equals("") ? ls : s + " · " + ls;
        }
        var q = (gSync == null) ? 0 : gSync.pending();
        if (q > 0) {
            var p = "بانتظار الرفع " + q.toString();
            s = s.equals("") ? p : s + " · " + p;
        }
        return s.equals("") ? null : s;
    }

    // "2026-11-13T20:00" -> "13/11 · 20:00"
    function fmtWhen(s) {
        if (s == null || s.equals("")) { return null; }
        var datePart = s;
        var timePart = "";
        var ti = s.find("T");
        if (ti != null) {
            datePart = s.substring(0, ti);
            timePart = s.substring(ti + 1, s.length());
        }
        var dd = "";
        var mm = "";
        if (datePart.length() >= 10) {
            mm = datePart.substring(5, 7);
            dd = datePart.substring(8, 10);
        }
        var hhmm = (timePart.length() >= 5) ? timePart.substring(0, 5) : timePart;
        if (!dd.equals("")) {
            return hhmm.equals("") ? (dd + "/" + mm) : (dd + "/" + mm + " · " + hhmm);
        }
        return s;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        Theme.fillBg(dc);
        dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, "جارٍ التحديث…",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Delegate for the loading view (no interaction needed).
class MatchListDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
}

// Handles selection from the match chooser menu.
class MatchMenuDelegate extends WatchUi.Menu2InputDelegate {
    var matches;
    var hasResume;

    function initialize(m, resume) {
        Menu2InputDelegate.initialize();
        matches = m;
        hasResume = resume;
    }

    function onSelect(item) {
        var id = item.getId() as Lang.String;

        if (id.equals("__resume__")) {
            var m = Match.fromDict(Store.loadActive());
            if (m != null) {
                gMatch = m;
                m.startTimer();
                var mv = new MainView();
                WatchUi.switchToView(mv, new MainDelegate(mv), WatchUi.SLIDE_LEFT);
            }
            return;
        }

        if (id.equals("__sync__")) {
            if (gSync != null) { gSync.flush(); }
            var lv = new MatchListView();
            WatchUi.switchToView(lv, new MatchListDelegate(), WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        if (id.equals("__new__")) {
            var sv = new SetupView();
            WatchUi.switchToView(sv, new SetupDelegate(sv), WatchUi.SLIDE_LEFT);
            return;
        }

        var idx = id.toNumber();
        if (idx != null && idx >= 0 && idx < matches.size()) {
            var sv2 = new SetupView();
            sv2.preload(matches[idx]);
            WatchUi.switchToView(sv2, new SetupDelegate(sv2), WatchUi.SLIDE_LEFT);
        }
    }
}
