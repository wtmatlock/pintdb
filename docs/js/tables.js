$(function () {
    $(".tsv-table").each(function () {
        const table = this;
        const $table = $(table);
        const tsvFileName = $table.data("tsv");
        const siteRoot = window.location.pathname.includes("/quickstart/") ? "../" : "./";
        const tsvPath = new URL(tsvFileName, new URL(siteRoot, window.location.href)).href;
        const status = document.createElement("p");
        let dataTable = null;
        let rowsLoaded = 0;
        let parseErrors = 0;
        let started = false;

        status.className = "pint-table-status";
        status.setAttribute("role", "status");
        status.setAttribute("aria-live", "polite");
        status.dataset.state = "idle";
        status.textContent = "Search data will load when this table is near view.";
        table.parentNode.insertBefore(status, table);

        function setSearchEnabled(enabled) {
            const input = $table.closest(".dataTables_wrapper").find(".dataTables_filter input");
            input.prop("disabled", !enabled);
            input.attr(
                "aria-label",
                enabled ? "Search all table records" : "Search will be available after loading completes"
            );
        }

        function showError(error) {
            console.error("Could not load TSV file:", tsvPath, error);
            status.dataset.state = "error";
            status.replaceChildren(
                document.createTextNode(
                    rowsLoaded
                        ? `Could not finish loading ${tsvFileName}. ${rowsLoaded.toLocaleString()} rows loaded; search is unavailable. `
                        : `Could not load ${tsvFileName}. `
                )
            );
            const retry = document.createElement("button");
            retry.className = "pint-table-retry";
            retry.type = "button";
            retry.textContent = "Retry";
            retry.addEventListener("click", function () {
                if (dataTable) {
                    dataTable.destroy();
                    dataTable = null;
                    table.replaceChildren();
                }
                rowsLoaded = 0;
                parseErrors = 0;
                started = false;
                status.dataset.state = "idle";
                status.textContent = "Retrying table load…";
                loadTable();
            }, { once: true });
            status.appendChild(retry);
        }

        function initializeTable(fields) {
            if (dataTable) {
                return;
            }
            dataTable = $table.DataTable({
                data: [],
                columns: fields.map(function (field) {
                    return { title: field, data: field, defaultContent: "" };
                }),
                pageLength: 10,
                lengthMenu: [10, 25, 50],
                searching: true,
                scrollX: true,
                autoWidth: false,
                deferRender: true,
                dom: "frtip"
            });
            setSearchEnabled(false);
        }

        function loadTable() {
            if (started) {
                return;
            }
            started = true;
            rowsLoaded = 0;
            parseErrors = 0;
            status.dataset.state = "loading";
            status.textContent = `Loading ${tsvFileName}…`;

            Papa.parse(tsvPath, {
                download: true,
                worker: true,
                header: true,
                skipEmptyLines: true,
                delimiter: "\t",
                chunkSize: 256 * 1024,
                chunk: function (results, parser) {
                    if (!results.meta.fields || results.meta.fields.length === 0) {
                        parser.abort();
                        showError(new Error("The TSV file did not contain a header row."));
                        return;
                    }
                    initializeTable(results.meta.fields);
                    if (results.data.length > 0) {
                        rowsLoaded += results.data.length;
                        dataTable.rows.add(results.data).draw(false);
                    }
                    status.textContent = `Loading ${tsvFileName}… ${rowsLoaded.toLocaleString()} rows ready. Full search will be available when loading finishes.`;
                    if (results.errors.length > 0) {
                        parseErrors += results.errors.length;
                        console.error("Errors while parsing TSV file:", tsvPath, results.errors);
                    }
                },
                complete: function (results) {
                    if (status.dataset.state === "error") {
                        return;
                    }
                    if (!dataTable && results.meta.fields && results.meta.fields.length > 0) {
                        initializeTable(results.meta.fields);
                    }
                    setSearchEnabled(true);
                    status.dataset.state = "loaded";
                    status.textContent = `${rowsLoaded.toLocaleString()} rows loaded. Search all records below.`;
                    if (parseErrors > 0) {
                        status.textContent += ` The parser reported ${parseErrors} issue(s); see the browser console for details.`;
                    }
                },
                error: showError
            });
        }

        if ("IntersectionObserver" in window) {
            const observer = new IntersectionObserver(function (entries) {
                if (entries.some(function (entry) { return entry.isIntersecting; })) {
                    observer.disconnect();
                    loadTable();
                }
            }, { rootMargin: "0px" });
            observer.observe(table);
        } else {
            loadTable();
        }
    });
});
