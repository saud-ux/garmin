import Toybox.Lang;
import Toybox.Communications;
import Toybox.System;

// Firebase Firestore REST sync. Same project/key as the website.
// Web API keys are not secrets; access is governed by Firestore rules.
class Sync {

    const PROJECT = "garmin-c3b62";
    const API_KEY = "AIzaSyCXJdmq1_KOXuZYJTcLnWlyAtduOREUrbs";
    const USER    = "saud";

    var _fetchCb;   // callback holder for list fetch

    function initialize() {
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

    function statusOf(match) {
        return match.phase.equals("done") ? "done" : "upcoming";
    }

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

    function encEvents(match) {
        var vals = [];
        for (var i = 0; i < match.events.size(); i++) {
            vals.add(encEvent(match.events[i]));
        }
        return sArr(vals);
    }

    function encLive(match) {
        return sMap({
            "phase"          => sStr(match.phase),
            "running"        => sBool(match.running),
            "elapsedSec"     => sInt(match.elapsedSec),
            "addedRunning"   => sBool(match.addedRunning),
            "addedTargetSec" => sInt(match.addedTargetSec),
            "addedElapsedSec"=> sInt(match.addedElapsedSec),
            "breakSec"       => sInt(match.breakSec)
        });
    }

    // Full create (watch-made match): writes the whole document.
    function pushFull(match) {
        var fields = {
            "id"      => sStr(match.id),
            "home"    => sMap({ "name" => sStr(match.homeName), "color" => sStr(match.homeColor) }),
            "away"    => sMap({ "name" => sStr(match.awayName), "color" => sStr(match.awayColor) }),
            "half"    => sInt(match.halfLen),
            "brk"     => sInt(match.brkLen),
            "status"  => sStr(statusOf(match)),
            "added1"  => sInt(match.added1),
            "added2"  => sInt(match.added2),
            "kickoff" => sStr(match.kickoff),
            "events"  => encEvents(match),
            "live"    => encLive(match),
            "date"    => sStr(""),
            "comp"    => sStr(""),
            "venue"   => sStr(""),
            "role"    => sStr("ar1")
        };
        commit(match.id, fields, null);
    }

    // Ongoing update: only the fields that change during play.
    // updateMask preserves website-set metadata (date/comp/venue/role).
    function pushLive(match) {
        var fields = {
            "status"  => sStr(statusOf(match)),
            "added1"  => sInt(match.added1),
            "added2"  => sInt(match.added2),
            "kickoff" => sStr(match.kickoff),
            "events"  => encEvents(match),
            "live"    => encLive(match)
        };
        var mask = [ "status", "added1", "added2", "kickoff", "events", "live" ];
        commit(match.id, fields, mask);
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

    function onPush(code, data) {
        if (code != 200) {
            System.println("FB push failed: " + code);
        }
    }

    // ---- read: list matches (for setup screen) ----
    function fetchMatches(cb) {
        _fetchCb = cb;
        var url = base() + "/users/" + USER + "/matches";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, { "key" => API_KEY }, options, method(:onFetch));
    }

    function onFetch(code, data) {
        var list = [];
        if (code == 200 && data != null && data.hasKey("documents")) {
            var docs = data["documents"];
            for (var i = 0; i < docs.size(); i++) {
                var m = decodeMatch(docs[i]);
                if (m != null) { list.add(m); }
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
            "status"    => fStr(f, "status", "upcoming")
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
