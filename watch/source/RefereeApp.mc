import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;
import Toybox.System;

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
        gSync.flush();          // upload whatever the last session could not send
        scheduleBackground();   // keep the match list fresh while the app is shut
    }

    // Hourly background pull. Registering again with the same period is
    // harmless, but we skip it when it is already set.
    function scheduleBackground() {
        try {
            if (!(Toybox has :Background)) { return; }
            if (Background.getTemporalEventRegisteredTime() == null) {
                Background.registerForTemporalEvent(new Time.Duration(3600));
            }
        } catch (e) {
            System.println("background register failed");
        }
    }

    // The background service stores the list itself; this is the fallback for
    // devices that only hand data back through the app.
    function onBackgroundData(data) as Void {
        if (data instanceof Lang.Array) {
            Store.saveList(data);
        }
    }

    function getServiceDelegate() {
        return [ new BgService() ];
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
