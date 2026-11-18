import Toybox.Lang;
import Toybox.Background;
import Toybox.System;

// Runs while the app is closed. Once an hour it pulls the match list from the
// website and saves it on the watch, so a match created on the site is already
// there before the app is ever opened — and still there with no phone nearby.
(:background)
class BgService extends System.ServiceDelegate {

    var _sync;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        _sync = new Sync();
        if (!_sync.online()) {
            Background.exit(null);   // no phone — try again next hour
            return;
        }
        _sync.fetchMatches(method(:onList));
    }

    function onList(list) as Void {
        if (list != null) {
            Store.saveList(list);
        }
        Background.exit(null);
    }
}
