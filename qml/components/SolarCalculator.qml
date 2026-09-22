import QtQuick 2.6
import "../js/solar.js" as Solar

QtObject {
    id: calculator

    // Compute sunrise/sunset for a given location and date
    // Returns { sunrise, sunset, solarNoon, polarDay, polarNight }
    function compute(lat, lon, date) {
        return Solar.solarData(date || new Date(), lat, lon);
    }

    // Format sunrise time for display
    function sunriseText(lat, lon) {
        var data = Solar.solarData(new Date(), lat, lon);
        if (data.polarDay) return qsTr("Polar day");
        if (data.polarNight) return qsTr("Polar night");
        return Solar.formatTime(data.sunrise);
    }

    // Format sunset time for display
    function sunsetText(lat, lon) {
        var data = Solar.solarData(new Date(), lat, lon);
        if (data.polarDay) return qsTr("Polar day");
        if (data.polarNight) return qsTr("Polar night");
        return Solar.formatTime(data.sunset);
    }

    // Get current subsolar point
    function subsolarPoint() {
        return Solar.subsolarPoint(new Date());
    }

    // Format time from a Date object
    function formatTime(d) {
        return Solar.formatTime(d);
    }
}
