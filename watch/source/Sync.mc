import Toybox.Lang;
import Toybox.Communications;
import Toybox.System;
import Toybox.Time;
import Toybox.PersistedContent;

// Firebase Firestore REST sync. Same project/key as the website.
// Web API keys are not secrets; access is governed by Firestore rules.
class Sync {

    const PROJECT = "garmin-c3b62";
    const API_KEY = "AIzaSyCXJdmq1_KOXuZYJTcLnWlyAtduOREUrbs";
    const USER    = "saud";

    var _fetchCb;      // callback holder for list fetch
    var _inflight;     // dict of the match currently being uploaded
    var _flushing;     // true while draining the offline queue
    var _anyQueued;    // in-memory hint: something is waiting to upload
    var _qn;           // cached queue size (screens redraw every second)
    var _link;         // cached phone-connection state
    var _linkAt;       // when _link was last read
    var _enqAt;        // last time we wrote to the offline queue

    function initialize() {
        _flushing = false;
        _qn = Store.queueSize();
        _anyQueued = _qn > 0;
        _link = false;
        _linkAt = 0;
        _enqAt = 0;
    }

    // The watch only reaches the internet through the phone. Re-read at most
    // once every 3 seconds — this is called from drawing code.
    function online() {
        var t = Time.now().value();
        if (t - _linkAt >= 3) {
            _linkAt = t;
            try {
                _link = System.getDeviceSettings().phoneConnected;
            } catch (e) {
                _link = false;
            }
        }
        return _link;
    }

    function pending() {
        return _qn;
    }

    function recount() {
        _qn = Store.queueSize();
        _anyQueued = _qn > 0;
    }

    function base() {
        return "https://firestore.googleapis.com/v1/projects/" + PROJECT +
               "/databases/(default)/documents";
    }

    function docName(id) {
        return "projects/" + PROJECT + "/databases/(default)/documents/users/" +
               USER + "/matches/" + id;
    }

    // ---- typed-value encoders ----
    function sStr(v)  { return { "stringValue"  => (v == null ? "" : v) }; }
    function sInt(v)  { return { "integerValue" => v.toString() }; }
    function sBool(v) { return { "booleanValue" => v }; }
    function sMap(f)  { return { "mapValue" => { "fields" => f } }; }
    function sArr(a)  { return { "arrayValue" => { "values" => a } }; }

    function encEvent(e) {
        var f = {
            "id"     => sStr(e["id"]),
            "kind"   => sStr(e["kind"]),
            "min"    => sInt(e["min"]),
            "team"   => sStr(e["team"]),
            "player" => sStr(e["player"]),
            "note"   => sStr(e.hasKey("note") ? e["note"] : "")
        };
        if (e.hasKey("second") && e["second"]) {
            f["second"] = sBool(true);
        }
        return sMap(f);
    }

    function encEvents(arr) {
        var vals = [];
        if (arr != null) {
            for (var i = 0; i < arr.size(); i++) {
                vals.add(encEvent(arr[i]));
            }
        }
        return sArr(vals);
    }

    function encLive(d) {
        return sMap({
            "phase"          => sStr(dv(d, "phase", "1st")),
            "running"        => sBool(dv(d, "running", false)),
            "elapsedSec"     => sInt(dv(d, "elapsedSec", 0)),
            "addedRunning"   => sBool(dv(d, "addedRunning", false)),
            "addedTargetSec" => sInt(dv(d, "addedTargetSec", 0)),
            "addedElapsedSec"=> sInt(dv(d, "addedElapsedSec", 0)),
            "breakSec"       => sInt(dv(d, "breakSec", 0))
        });
    }

    function dv(d, k, def) {
        if (d != null && d.hasKey(k) && d[k] != null) { return d[k]; }
        return def;
    }

    // A watch-made match needs the whole document; a website match keeps its
    // own metadata (date, competition, venue, role) via updateMask.
    function pushFull(match) {
        attempt(match.toDict(), true, true);
    }

    // Routine clock update — queued at most once every 30s while offline.
    function pushLive(match) {
        attempt(match.toDict(), false, false);
    }

    // A goal, a card, a half ending: always recorded for upload right away.
    function pushNow(match) {
        attempt(match.toDict(), false, true);
    }

    // Nothing is ever lost: offline or failed uploads go to the local queue.
    function attempt(d, full, force) {
        if (!online()) {
            saveForLater(d, force);
            return;
        }
        _inflight = d;
        send(d, full);
    }

    // Writing to watch storage costs flash, so only on real changes or once
    // every 30 seconds. The active-match snapshot covers anything in between.
    function saveForLater(d, force) {
        var t = Time.now().value();
        if (force || !_anyQueued || t - _enqAt >= 30) {
            _enqAt = t;
            Store.enqueue(d);
            recount();
        }
    }

    function send(d, full) {
        var phase = dv(d, "phase", "1st");
        var fields = {
            "status"  => sStr(phase.equals("done") ? "done" : "upcoming"),
            "added1"  => sInt(dv(d, "added1", 0)),
            "added2"  => sInt(dv(d, "added2", 0)),
            "kickoff" => sStr(dv(d, "kickoff", "home")),
            "events"  => encEvents(dv(d, "events", [])),
            "live"    => encLive(d)
        };
        var mask = [ "status", "added1", "added2", "kickoff", "events", "live" ];
        if (full) {
            fields["id"]    = sStr(dv(d, "id", ""));
            fields["home"]  = sMap({ "name" => sStr(dv(d, "homeName", "")), "color" => sStr(dv(d, "homeColor", "green")) });
            fields["away"]  = sMap({ "name" => sStr(dv(d, "awayName", "")), "color" => sStr(dv(d, "awayColor", "blue")) });
            fields["half"]  = sInt(dv(d, "halfLen", 45));
            fields["brk"]   = sInt(dv(d, "brkLen", 15));
            fields["date"]  = sStr("");
            fields["comp"]  = sStr("");
            fields["venue"] = sStr("");
            fields["role"]  = sStr("ar1");
            mask = null;
        }
        commit(dv(d, "id", ""), fields, mask);
    }

    // Send the oldest waiting match; the rest follow one by one on success.
    function flush() {
        if (!online() || _flushing) { return; }
        var q = Store.queue();
        _qn = q.size();
        if (_qn == 0) { _anyQueued = false; return; }
        var d = q[0];
        _flushing = true;
        _inflight = d;
        send(d, dv(d, "isNew", false));
    }

    function commit(id, fields, mask) {
        var write = { "update" => { "name" => docName(id), "fields" => fields } };
        if (mask != null) {
            write["updateMask"] = { "fieldPaths" => mask };
        }
        var body = { "writes" => [ write ] };
        var url = base() + ":commit?key=" + API_KEY;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, body, options, method(:onPush));
    }

    function onPush(code as Lang.Number, data as Null or Lang.ByteArray or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        var d = _inflight;
        _inflight = null;
        var wasFlush = _flushing;
        _flushing = false;
        if (code == 200) {
            if (d != null && _anyQueued) {
                Store.dequeue(dv(d, "id", null));
                recount();
            }
            if (wasFlush) { flush(); }
        } else {
            System.println("FB push failed: " + code);
            if (d != null) {
                saveForLater(d, false);
            }
        }
    }

    // ---- read: list matches (for setup screen) ----
    function fetchMatches(cb) {
        _fetchCb = cb;
        if (!online()) {
            cb.invoke(null);   // null = could not reach the website
            return;
        }
        var url = base() + "/users/" + USER + "/matches";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, { "key" => API_KEY }, options, method(:onFetch));
    }

    function onFetch(code as Lang.Number, data as Null or Lang.ByteArray or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        if (code != 200) {
            if (_fetchCb != null) { _fetchCb.invoke(null); }
            return;
        }
        var list = [];
        if (data instanceof Lang.Dictionary) {
            var dd = data as Lang.Dictionary;
            if (dd.hasKey("documents")) {
                var docs = dd["documents"] as Lang.Array;
                for (var i = 0; i < docs.size(); i++) {
                    var m = decodeMatch(docs[i]);
                    if (m != null) { list.add(m); }
                }
            }
        }
        if (_fetchCb != null) {
            _fetchCb.invoke(list);
        }
    }

    function decodeMatch(doc) {
        if (doc == null || !doc.hasKey("fields")) { return null; }
        var f = doc["fields"];
        var name = doc.hasKey("name") ? doc["name"] : "";
        var id = lastSeg(name);
        return {
            "id"        => id,
            "homeName"  => mapStr(f, "home", "name", "الأرض"),
            "homeColor" => mapStr(f, "home", "color", "green"),
            "awayName"  => mapStr(f, "away", "name", "الضيف"),
            "awayColor" => mapStr(f, "away", "color", "blue"),
            "halfLen"   => fInt(f, "half", 45),
            "brkLen"    => fInt(f, "brk", 15),
            "status"    => fStr(f, "status", "upcoming"),
            "date"      => fStr(f, "date", ""),
            "comp"      => fStr(f, "comp", "")
        };
    }

    function lastSeg(s) {
        var parts = toArray(s, '/');
        return parts.size() > 0 ? parts[parts.size() - 1] : s;
    }

    function toArray(s, sep) {
        var out = [];
        var cur = "";
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == sep) { out.add(cur); cur = ""; }
            else { cur += chars[i].toString(); }
        }
        out.add(cur);
        return out;
    }

    function fStr(f, key, def) {
        if (f.hasKey(key) && f[key].hasKey("stringValue")) { return f[key]["stringValue"]; }
        return def;
    }

    function fInt(f, key, def) {
        if (f.hasKey(key) && f[key].hasKey("integerValue")) {
            return f[key]["integerValue"].toNumber();
        }
        return def;
    }

    function mapStr(f, mapKey, subKey, def) {
        if (f.hasKey(mapKey) && f[mapKey].hasKey("mapValue")) {
            var mf = f[mapKey]["mapValue"]["fields"];
            if (mf.hasKey(subKey) && mf[subKey].hasKey("stringValue")) {
                return mf[subKey]["stringValue"];
            }
        }
        return def;
    }
}
