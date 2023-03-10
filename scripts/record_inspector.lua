function onInit()
    self.inspectorSourceNode = ""
end


function onDrop(x, y, dragdata)
    if dragdata.getType() ~= "shortcut" then return end

    local class, sourcePath = dragdata.getShortcutData()
    local sourceNode = DB.findNode(sourcePath)
    if (sourceNode or "") == "" then return end

    self.inspectorSourceNode = getSourceNodeRoot(sourcePath)
    local sInspectedRecordType = LibraryData.getRecordTypeFromRecordPath(sourcePath)
    local sRecordName = DB.getValue(sourceNode, "name", sourceNode.getName())
    local sName = "Template Parsed from: " .. sRecordName .. "(" .. sInspectedRecordType .. ")"
    local destNode = DB.createChild("record_template")
    parseNodeToTemplate(sourceNode, DB.createChild(destNode, "record_rows"))

    DB.setValue(destNode, "name", "string", sName)
    DB.setValue(destNode, "record_type", "string", sInspectedRecordType)
    DB.setValue(destNode, "record_name_field", "string", "name")
    Interface.openWindow("record_template", destNode)
    self.inspectorSourceNode = ""
end

function getSourceNodeRoot(sourceNode)
    local inspectorSourceNode = sourceNode:gsub("%.", "%%."):gsub("%-", "%%-").."%."
    if inspectorSourceNode:find("@") then
        return StringManager.split(inspectorSourceNode, "@")[1]
    else
        return inspectorSourceNode
    end
end

function parseNodeToTemplate(sourceNode, record_rows)
    for nodeName, node in pairs(DB.getChildren(sourceNode)) do
        parseAndAddNode(node, record_rows)
    end
end

local emptyNodeNamePat = '^id%-[0-9][0-9][0-9][0-9][0-9]$'

function parseAndAddNode(sourceNode, dstParent)
    local childNode = DB.createChild(dstParent)
    local sourceType = DB.getType(sourceNode)
    local nodeName = DB.getName(sourceNode)
    if (nodeName:find(emptyNodeNamePat) or "") == "" then
        DB.setValue(childNode, "name", "string", nodeName)
    end
    if sourceType == "node" then
        DB.setValue(childNode, "nodeType", "string", "intermediate")
        local sub_record_rows = DB.createChild(childNode, "sub_record_rows")
        for _, node in pairs(DB.getChildren(sourceNode)) do
            parseAndAddNode(node, sub_record_rows)
        end
        if DB.getChildCount(sub_record_rows) == 0 then
            DB.deleteNode(childNode)
        end
    else
        nodeType, nodeVal = getNodeDef(sourceNode)
        if nodeVal == "" then
            DB.deleteNode(childNode)
        else
            if nodeType == "formattedtext" then
                DB.setValue(childNode, "nodeFmtValue", "formattedtext", nodeVal)
            else
                DB.setValue(childNode, "nodeValue", "string", nodeVal)
            end
            DB.setValue(childNode, "nodeType", "string", nodeType)
        end
    end
end

function getNodeDef(node)
    local nodeType = DB.getType(node)
    local nodeValue = DB.getValue(node, "", "")
    if nodeType == "dice" then
        nodeValue = StringManager.convertDiceToString(nodeValue)
    elseif nodeType == "windowreference" then
        local class, link = DB.getValue(node, "")
        local linkName = DB.getValue(node,  "name")
        if (class ~= "") and (link ~="") and (linkName ~= "") then
            nodeValue = "||"..class.."|"..link.."|" .. linkName .. "||"
        else
            nodeValue = ""
        end
    elseif nodeType == "number" then
        if nodeValue == "0" or nodeValue == 0 then
            nodeValue = ""
        end
    end
    return nodeType, nodeValue
end