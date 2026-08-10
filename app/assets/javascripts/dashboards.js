//= require flot/jquery.flot.js
//= require flot/jquery.flot.tooltip.min.js
//= require flot/jquery.flot.resize.js
//= require flot/jquery.flot.pie.js
//= require flot/jquery.flot.time.js
//= require flot/jquery.flot.spline.js
//= require sparkline/jquery.sparkline.min.js
//= require chartjs/Chart.min.js
//= require jvectormap/jquery-jvectormap-2.0.2.min.js
//= require jvectormap/jquery-jvectormap-world-mill-en.js

document.addEventListener("DOMContentLoaded", function () {
    const data = JSON.parse(document.getElementById("dashboard-data").textContent);

    const flotOptions = {
        series: {
            lines:   { show: false, fill: true },
            splines: { show: true, tension: 0.4, lineWidth: 1, fill: 0.4 },
            points:  { radius: 1, show: true },
            shadowSize: 2
        },
        grid:    { hoverable: true, clickable: true, tickColor: "#d5d5d5", borderWidth: 1, color: "#d5d5d5" },
        colors:  ["#D1DADE", "#1ab394", "#32ab34", "#f8ac59", "#ff0000"],
        xaxis:   { ticks: 24 },
        yaxis:   { ticks: 4, min: 0 },
        tooltip: false
    };

    if ($("#flot-dashboard-chart").length) {
        $.plot($("#flot-dashboard-chart"),
            [data.total, data.finished, data.active, data.failed, data.denied],
            flotOptions);
    }

    if ($("#flot-dashboard-chart-7days").length) {
        $.plot($("#flot-dashboard-chart-7days"),
            [data.total_w, data.finished_w, data.active_w, data.failed_w, data.denied_w],
            flotOptions);
    }

    const doughnutOptions = { responsive: false, legend: { display: false } };

    new Chart(document.getElementById("doughnut_accesses").getContext("2d"), {
        type: "doughnut",
        options: doughnutOptions,
        data: {
            labels: ["Active Policies", "Inactive Policies"],
            datasets: [{ data: [data.ap_active, data.ap_inactive], backgroundColor: ["#a3e1d4", "#1c84c6"] }]
        }
    });

    new Chart(document.getElementById("doughnut_gateway_users").getContext("2d"), {
        type: "doughnut",
        options: doughnutOptions,
        data: {
            labels: ["Login Users", "Groups"],
            datasets: [{ data: [data.gw_logins, data.gw_groups], backgroundColor: ["#a3e1d4", "#1c84c6"] }]
        }
    });

    new Chart(document.getElementById("doughnut_target_users").getContext("2d"), {
        type: "doughnut",
        options: doughnutOptions,
        data: {
            labels: ["Login Users", "Regex Users", "Mapping Users", "Groups"],
            datasets: [{ data: [data.tu_logins, data.tu_regex, data.tu_mapping, data.tu_groups], backgroundColor: ["#1ab394", "#dedede", "#f8ac59", "#1c84c6"] }]
        }
    });

    new Chart(document.getElementById("doughnut_targets").getContext("2d"), {
        type: "doughnut",
        options: doughnutOptions,
        data: {
            labels: ["Static", "Dynamic", "Domains", "Networks", "Groups"],
            datasets: [{ data: [data.t_statics, data.t_dynamics, data.t_domains, data.t_networks, data.t_groups], backgroundColor: ["#1ab394", "#dedede", "#f8ac59", "#ED5565", "#1c84c6"] }]
        }
    });
});
