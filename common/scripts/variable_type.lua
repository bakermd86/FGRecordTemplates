local subWindowMap = {
    ["Record Type"] = "insert_record_type_pane_inline",
    ["Exclusive Group"] = "insert_exclusive_group_pane_inline"
}

function onInit()
    super.onInit()
    local insertTypes = {"Record Type", "Exclusive Group"}
    self.addItems(insertTypes)
end

function onValueChanged()
    local showWindow = false
    local paneClass = subWindowMap[getValue()]
    if (paneClass or "") ~= "" then
        window.variableValSubwindow.setValue(paneClass, window.getDatabaseNode())
        showWindow = true
    else
        window.variableValSubwindow.setValue()
    end
--     window.variableName.setEnabled(getValue() ~= "Custom String")
    window.variableValSubwindow.setVisible(showWindow)
end