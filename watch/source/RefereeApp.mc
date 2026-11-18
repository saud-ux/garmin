import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Global singleton for the active match. Created when a match starts.
var gMatch = null;
// Global Firebase sync helper.
var gSync = null;
// Global reference to the main match screen (for toasts from pushed views).
var gMainView = null;

class RefereeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        gSync = new Sync();
        gSync.flush();   // upload whatever the last session could not send
    }

    function onStop(state as Dictionary?) as Void {
        if (gMatch != null) {
            gMatch.stopTimer();
            gMatch.persist();   // leaving the app must never lose the match
        }
    }

    // First screen: match chooser (never auto-selects).
    function getInitialView() {
        var view = new MatchListView();
        return [ view, new MatchListDelegate() ];
    }
}

function getApp() as RefereeApp {
    return Application.getApp() as RefereeApp;
}
