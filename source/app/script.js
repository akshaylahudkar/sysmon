// ── CONFIG ───────────────────────────────────────────────────────
var REFRESH_MS = 4000;
var STATUS_URL = "status.json"; // same directory as this page — the
                                 // background loop launch.sh starts writes
                                 // here on a timer

function escapeHtml(s) {
    return String(s)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function statRow(label, value) {
    return "<tr><td class='stat-label'>" + escapeHtml(label) + "</td>" +
           "<td class='stat-value'>" + escapeHtml(value) + "</td></tr>";
}

function fetchStatus() {
    var xhr = new XMLHttpRequest();
    // Cache-buster query param — enableCaching is off in config.xml, but
    // this also protects against any intermediate caching of a local file.
    xhr.open("GET", STATUS_URL + "?t=" + Date.now(), true);
    xhr.timeout = 5000;

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== 4) { return; }
        if (xhr.status === 200 || xhr.status === 0) {
            // status 0 is normal for successful file:// XHR in this webview
            var data;
            try { data = JSON.parse(xhr.responseText); }
            catch (e) { setStatus("Parse error"); return; }
            renderUI(data);
            setStatus("Updated " + data.time);
        } else {
            setStatus("Read error " + xhr.status);
        }
    };
    xhr.ontimeout = function() { setStatus("Timeout reading status"); };
    xhr.onerror   = function() { setStatus("Cannot read status.json"); };
    xhr.send();
}

function renderUI(data) {
    var bat = data.battery || {};
    var batHtml = "<table class='stat-table'>" +
        statRow("Charge", (bat.capacity != null ? bat.capacity + "%" : "--") +
                (bat.status ? " (" + bat.status + ")" : "")) +
        statRow("Health", bat.health || "--") +
        statRow("Capacity retention", bat.retention_pct != null ? bat.retention_pct + "%" : "--") +
        statRow("Cycle count", bat.cycles != null ? bat.cycles : "--") +
        statRow("Temperature", bat.temp_c != null ? bat.temp_c + " °C" : "--") +
        "</table>";
    document.getElementById("battery").innerHTML = batHtml;

    var ram = data.ram || {};
    var totalMb = ram.total_kb != null ? Math.round(ram.total_kb / 1024) : null;
    var availMb = ram.available_kb != null ? Math.round(ram.available_kb / 1024) : null;
    var freeMb = ram.free_kb != null ? Math.round(ram.free_kb / 1024) : null;
    var usedPct = 0;
    if (totalMb && availMb != null) {
        usedPct = Math.round((totalMb - availMb) / totalMb * 100);
    }
    var ramHtml = "<table class='stat-table'>" +
        statRow("Total", totalMb != null ? totalMb + " MB" : "--") +
        statRow("Available", availMb != null ? availMb + " MB" : "--") +
        statRow("Free", freeMb != null ? freeMb + " MB" : "--") +
        statRow("Used", usedPct + "%") +
        "</table>";
    document.getElementById("ram").innerHTML = ramHtml;
    document.getElementById("ram-bar-fill").style.width = usedPct + "%";

    var cpu = data.cpu || {};
    var busyLabel = "--";
    if (cpu.load1 != null && cpu.cores) {
        var perCore = cpu.load1 / cpu.cores;
        if (perCore < 0.7) { busyLabel = "Idle"; }
        else if (perCore < 1.0) { busyLabel = "Normal"; }
        else if (perCore < 2.0) { busyLabel = "Busy"; }
        else { busyLabel = "Overloaded"; }
        busyLabel += " (" + Math.round(perCore * 100) + "% per core)";
    }
    var cpuHtml = "<table class='stat-table'>" +
        statRow("Status", busyLabel) +
        statRow("Load (1/5/15 min)", (cpu.load1 != null ? cpu.load1 : "--") + " / " +
                (cpu.load5 != null ? cpu.load5 : "--") + " / " +
                (cpu.load15 != null ? cpu.load15 : "--")) +
        statRow("Cores", cpu.cores != null ? cpu.cores : "--") +
        "</table>";
    document.getElementById("cpu").innerHTML = cpuHtml;

    var storage = data.storage || {};
    var storageHtml = "<table class='stat-table'>" +
        statRow("Size", storage.size || "--") +
        statRow("Used", (storage.used || "--") + " (" + (storage.used_pct || "--") + ")") +
        statRow("Available", storage.available || "--") +
        "</table>";
    document.getElementById("storage").innerHTML = storageHtml;
    var storagePct = storage.used_pct ? parseInt(storage.used_pct, 10) : 0;
    document.getElementById("storage-bar-fill").style.width =
        (isNaN(storagePct) ? 0 : storagePct) + "%";

    var uptime = data.uptime || {};
    var systemHtml = "<table class='stat-table'>" +
        statRow("Uptime", uptime.text || "--") +
        statRow("SoC temperature", data.soc_temp_c != null ? data.soc_temp_c + " °C" : "--") +
        "</table>";
    document.getElementById("system").innerHTML = systemHtml;

    var dev = data.device || {};
    var devLine = [dev.firmware, dev.kernel, dev.arch].filter(function(v) { return v; }).join("  ·  ");
    document.getElementById("device-line").innerHTML = escapeHtml(devLine);

    var jb = data.jailbreak || {};
    function yesNo(v) { return v ? "Yes" : "No"; }
    var jbHtml = "<table class='stat-table'>" +
        statRow("Jailbreak", jb.name || "--") +
        statRow("KPM", jb.kpm_version || "--") +
        statRow("kterm / KOReader / KindleForge",
                yesNo(jb.kterm) + " / " + yesNo(jb.koreader) + " / " + yesNo(jb.kindleforge)) +
        "</table>";
    document.getElementById("jailbreak").innerHTML = jbHtml;
}

function setStatus(msg) {
    document.getElementById("status-line").innerHTML = msg;
}

document.addEventListener("DOMContentLoaded", function() {
    fetchStatus();
    setInterval(fetchStatus, REFRESH_MS);
});
