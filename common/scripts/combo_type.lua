function onInit()
    super.onInit()
    local nodeTypes = {"number", "string", "formattedtext", "dice", "windowreference", "token", "intermediate", "copy child"}
    self.addItems(nodeTypes)
end

function onValueChanged()
    if getValue() == "intermediate" then
        window.nodeCollapseWindow.setVisible(true)
        window.nodeValWindow.setVisible(false)
        local show_rows = DB.getValue(window.getDatabaseNode(), "showRows", 0) == 0
        window.sub_record_rows.setVisible(show_rows)
        if window.sub_record_rows.getWindowCount() == 0 then
            window.sub_record_rows.createWindow()
        end
    elseif getValue() == "formattedtext" then
        window.sub_record_rows.setVisible(false)
        window.nodeCollapseWindow.setVisible(true)
        window.nodeValWindow.setValue("node_formatted_text_win", window.getDatabaseNode())
        local show_rows = DB.getValue(window.getDatabaseNode(), "showRows", 0) == 0
        window.nodeValWindow.setVisible(show_rows)
    else
        window.nodeCollapseWindow.setVisible(false)
        window.sub_record_rows.setVisible(false)
        window.nodeValWindow.setVisible(true)
        window.nodeValWindow.setValue("node_string_val_win", window.getDatabaseNode())
    end
end