c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 9999
# c.ServerApp.root_dir = ''
c.ServerApp.allow_password_change = False
c.NotebookApp.open_browser = False
c.ServerApp.jpserver_extensions = {"jupyter_mcp_server": True}

# JupyterLab commands exposed as MCP tools by jupyter-mcp-tools (ids are `namespace:command` with
# `:` -> `_`). These run inside the user's open JupyterLab browser tab, so they only work while a tab
# is open. Ids are the real JupyterLab 4.x command ids (several ids in the upstream jupyter-mcp-tools
# README, e.g. `kernel_restart`, do not exist in JupyterLab). Deliberately excluded:
# - filebrowser_upload / filebrowser_download: open a file picker or save to the human's browser and
#   never transfer bytes to the MCP client
# - docmanager_delete / docmanager_rename / docmanager_save-as, kernelmenu_change, kernelmenu_restart,
#   console_restart-kernel: block on a modal dialog (confirm / rename / kernel selection) that needs a
#   human click (jupyter-mcp-server's own restart_notebook tool restarts a kernel without the UI)
# See https://jupyter-mcp-server.datalayer.tech/operations/tools-jupyterlab/#allowed-tools
c.JupyterMCPServerExtensionApp.allowed_jupyter_mcp_tools = ",".join([
    # notebook
    "notebook_run-all-cells",
    "notebook_get-selected-cell",
    "notebook_append-execute",
    "notebook_insert-cell-below",
    "notebook_insert-cell-above",
    "notebook_delete-cell",
    "notebook_cut-cell",
    "notebook_copy-cell",
    "notebook_paste-cell-below",
    "notebook_paste-cell-above",
    "notebook_move-cursor-down",
    "notebook_move-cursor-up",
    "notebook_extend-marked-cells-below",
    "notebook_extend-marked-cells-above",
    "notebook_move-cell-up",
    "notebook_move-cell-down",
    "notebook_split-cell-at-cursor",
    "notebook_merge-cell-above",
    "notebook_merge-cell-below",
    "notebook_run-cell",
    "notebook_run-cell-and-select-next",
    "notebook_run-cell-and-insert-below",
    "notebook_change-cell-to-code",
    "notebook_change-cell-to-markdown",
    "notebook_change-cell-to-raw",
    # console
    "console_create",
    "console_clear",
    "console_interrupt-kernel",
    "console_inject",
    # document management
    "docmanager_open",
    "docmanager_new-untitled",
    "docmanager_save",
    "docmanager_duplicate",
    # file browser
    "filebrowser_go-to-path",
    "filebrowser_refresh",
    "filebrowser_toggle-hidden-files",
    "filebrowser_create-new-directory",
    # kernel
    "kernelmenu_interrupt",
    "kernelmenu_shutdown",
    "kernelmenu_reconnect-to-kernel",
    # UI / layout
    "application_toggle-left-area",
    "application_toggle-right-area",
    "application_toggle-presentation-mode",
    "apputils_change-theme",
    "editmenu_open",
    "filemenu_open",
    "helpmenu_open",
    # search
    "documentsearch_start",
    "documentsearch_highlightNext",
    "documentsearch_highlightPrevious",
    # terminal
    "terminal_create-new",
    "terminal_refresh",
])
