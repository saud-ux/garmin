import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;

// Local persistence on the watch. Everything the app shows must survive
// a lost phone connection, an app exit, or the watch powering off.
//   mlist  : last known match list from the website (chooser)
//   lsync  : epoch seconds of the last successful list fetch
//   active : the match being refereed right now (resume after exit/crash)
//   queue  : matches whose data has not reached the website yet
module Store {

    const K_LIST   = "mlist";
    const K_SYNC   = "lsync";
    const K_ACTIVE = "active";
    const K_QUEUE  = "queue";
    const MAX_LIST = 20;
    const MAX_QUEUE = 12;

    function get(k, def) {
        var v = null;
        try {
            v = Application.Storage.getValue(k);
        } catch (e) {
            v = null;
        }
        return v == null ? def : v;
    }

    function put(k, v) {
        try {
            Application.Storage.setValue(k, v);
        } catch (e) {
        }
    }

    function drop(k) {
        try {
            Application.Storage.deleteValue(k);
        } catch (e) {
        }
    }

    function now() {
        return Time.now().value();
    }

    // ---- match list cache ----
    function saveList(list) {
        var keep = [];
        for (var i = 0; i < list.size() && i < MAX_LIST; i++) {
            keep.add(list[i]);
        }
        put(K_LIST, keep);
        put(K_SYNC, now());
    }

    function loadList() {
        var v = get(K_LIST, []);
        return v instanceof Lang.Array ? v : [];
    }

    function lastSync() {
        var v = get(K_SYNC, 0);
        return v instanceof Lang.Number ? v : 0;
    }

    // "قبل 4 د" / "قبل 3 س" / "قبل 2 ي" / null when never synced
    function lastSyncText() {
        var t = lastSync();
        if (t <= 0) { return null; }
        var d = now() - t;
        if (d < 0) { d = 0; }
        if (d < 60)    { return "محدّثة الآن"; }
        if (d < 3600)  { return "آخر تحديث قبل " + (d / 60).toString() + " د"; }
        if (d < 86400) { return "آخر تحديث قبل " + (d / 3600).toString() + " س"; }
        return "آخر تحديث قبل " + (d / 86400).toString() + " ي";
    }

    // ---- active match (resume) ----
    function saveActive(d) {
        put(K_ACTIVE, d);
    }

    function loadActive() {
        var v = get(K_ACTIVE, null);
        return v instanceof Lang.Dictionary ? v : null;
    }

    function clearActive() {
        drop(K_ACTIVE);
    }

    // ---- upload queue ----
    function queue() {
        var v = get(K_QUEUE, []);
        return v instanceof Lang.Array ? v : [];
    }

    // Replace any earlier copy of the same match, keep newest last.
    function enqueue(d) {
        if (d == null || !d.hasKey("id")) { return; }
        var q = queue();
        var out = [];
        for (var i = 0; i < q.size(); i++) {
            var e = q[i];
            if (!(e instanceof Lang.Dictionary) || !e.hasKey("id")) { continue; }
            if (!e["id"].equals(d["id"])) { out.add(e); }
        }
        out.add(d);
        while (out.size() > MAX_QUEUE) {
            out.remove(out[0]);
        }
        put(K_QUEUE, out);
    }

    function dequeue(id) {
        if (id == null) { return; }
        var q = queue();
        var out = [];
        for (var i = 0; i < q.size(); i++) {
            var e = q[i];
            if (!(e instanceof Lang.Dictionary) || !e.hasKey("id")) { continue; }
            if (!e["id"].equals(id)) { out.add(e); }
        }
        put(K_QUEUE, out);
    }

    function queueSize() {
        return queue().size();
    }
}
