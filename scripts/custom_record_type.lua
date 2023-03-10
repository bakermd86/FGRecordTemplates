local parsedVariables = {}
local parsedNodes = {}
local varSourceMap = {
    ["Record Type"] = "insertRecordClass",
    ["Exclusive Group"] = "insertExclusiveGroup"
}
local _orgOnButtonPress = nil

function onInit()
    _orgOnButtonPress = window.generate.onButtonPress
    window.generate.onButtonPress = onGeneratePress
end

function onGeneratePress()
    math.randomseed(os.time() - os.clock() * 1000);
    _orgOnButtonPress()
    local sOriginal = DB.getValue(window.generate.nodeTarget, "text", "")
    local sText = parseRecordTemplates(sOriginal)
    DB.setValue(window.generate.nodeTarget, "text", "formattedtext", sText)
end

local _recordTemplateMatch = '()<link class="record_template" recordname="([^"]+)">[^<]+</link>()'

function parseRecordTemplates(sOriginal)
    local sText = ""
    local cursor = 1
    for sIdx, recordNodeStr, eIdx in sOriginal:gmatch(_recordTemplateMatch) do
        if (recordNodeStr or "") ~= "" then
            parsedVariables = {}
            parsedNodes = {}
            local resolvedNodeVals  = {}
            local recordNode = DB.findNode(recordNodeStr)
            local recordNodeType = DB.getValue(recordNode, "record_type", "")

            parseNodes(recordNode)
            parseVariables(recordNode)
            resolvedNodeVals, parsedVariables = resolveTemplateBody(getTemplateResBody())
            resolveVariables()
            resolvedNodeVals = resolveNodeVals(resolvedNodeVals)
            resolvedNodeVals = resolveLinksInRecords(resolvedNodeVals)

            local generatedRecordNode = writeResolvedRecord(resolvedNodeVals, recordNodeType)

            sText = sText .. sOriginal:sub(cursor, sIdx-1) .. formatResolvedRecordLink(generatedRecordNode, recordNodeType)
            cursor = eIdx
        end
    end
    sText = sText .. sOriginal:sub(cursor)
    return sText
end

function formatResolvedRecordLink(generatedRecordNode, recordNodeType)
    return '<link class="' .. recordNodeType .. '" recordname="' .. generatedRecordNode.getNodeName() .. '">' ..
                DB.getValue(generatedRecordNode, "name") ..  "</link>"
end

function writeResolvedRecord(resolvedNodeVals, recordNodeType)
    local generatedRecordNode = DB.createChild(window.generate.nodeTarget, recordNodeType).createChild()
    for _, nodeValDef in ipairs(resolvedNodeVals) do
        local nodeName = nodeValDef["nodeName"]
        local nodeType = nodeValDef["nodeType"]
        local nodeValue = nodeValDef["nodeValue"]
        if nodeType == "windowreference" then
            DB.setValue(generatedRecordNode, nodeName, nodeType, nodeValue["linkClass"], nodeValue["linkPath"])
        elseif nodeType == "copy child" then
            local dstParentNode = DB.createChild(generatedRecordNode, nodeName)
            local dstNode = DB.createChild(dstParentNode)
            if nodeValue ~= "" and DB.findNode(nodeValue) then
                DB.copyNode(nodeValue, dstNode)
            end
        elseif nodeType == "formattedtext" then
            DB.setValue(generatedRecordNode, nodeName, nodeType, unEscapeXml(nodeValue))
        else
            DB.setValue(generatedRecordNode, nodeName, nodeType, nodeValue)
        end
    end
    return generatedRecordNode
end

function resolveLinksInRecords(sourceNodes)
    local recordVals = {}
    for _, nodeValDef in ipairs(sourceNodes) do
        table.insert(recordVals, resolveRecordLinks(nodeValDef))
    end
    return recordVals
end


local nodeChildPat = '()(%|%|[^|]*%|[^|]*%|[^|]*%|%|)%.?([a-zA-Z0-9_-]*)()'
local nodePathElems = '%|%|([^|]*)%|([^|]*)%|([^|]*)%|%|'

function resolveRecordLinks(nodeValDef)
    local nodeType = nodeValDef["nodeType"]
    local nodeName = nodeValDef["nodeName"]
    local nodeValue = nodeValDef["nodeValue"]
    local cursor = 1
    local replaceVal = ""
    for sIdx, linkBody, subVal, eIdx in nodeValue:gmatch(nodeChildPat) do
        local subValueStr = ""
        _, _, linkClass, linkPath, junk = linkBody:find(nodePathElems)
        if linkClass ~= "" and linkPath ~= "" then
            if nodeType == "windowreference" then
                local resolvedDisplayClass = LibraryData.getRecordDisplayClass(linkClass, linkPath)
                if (resolvedDisplayClass or "") == "" then
                    resolvedDisplayClass = linkClass
                end
                nodeValDef["nodeValue"] = {
                    ["linkPath"] = linkPath,
                    ["linkClass"] = resolvedDisplayClass
                }
            elseif nodeType == "copy child" then
                if (linkPath or "") ~= "" then
                    nodeValDef["nodeValue"] = linkPath
                end
            elseif (subVal or "") ~= "" then
                subValueStr = DB.getText(DB.findNode(linkPath), subVal, "")
                replaceVal = replaceVal .. nodeValue:sub(cursor, sIdx-1) .. subValueStr
                cursor = eIdx
--                 nodeValDef["nodeValue"] = DB.getValue(DB.findNode(linkPath), subVal, subVal .. " not found")
            end
        end
    end
    if replaceVal ~= "" then
        replaceVal = replaceVal .. nodeValue:sub(cursor)
        nodeValDef["nodeValue"] = replaceVal
    end
    return nodeValDef
end

function resolveNodeVals(sourceNodes)
    local recordVals = {}
    for _, nodeValDef in ipairs(sourceNodes) do
        table.insert(recordVals, resolveNodeVal(nodeValDef))
    end
    return recordVals
end

function resolveNodeVal(nodeValDef)
    local nodeName = nodeValDef["nodeName"]
    local nodeType = nodeValDef["nodeType"]
    local nodeValue = nodeValDef["nodeValue"]
    nodeValDef["nodeValue"] = resolveGroupVars(nodeValue, nodeType)
    return nodeValDef
end

local splitNodeValPat = '()([a-zA-Z0-9_]+)([. ]*)()'

function resolveGroupVars(nodeValue, nodeType)
    local processedValue = ""
    if nodeValue ~= "" then
        local cursor = 1
        for sIdx, word, delim, eIdx in nodeValue:gmatch(splitNodeValPat) do
            local processedWord = word
            if (parsedVariables[word] or "") ~= "" then
                if parsedVariables[word]["varType"] == "Exclusive Group" then
                    processedWord = getExclusiveGroupVal(word)
                elseif parsedVariables[word]["varType"] == "Record Type" then
                    processedWord = formatResolvedRecord(word, nodeType)
                end
            end
            processedValue = processedValue .. nodeValue:sub(cursor, sIdx-1) .. processedWord .. delim
            cursor = eIdx
        end
        processedValue = processedValue .. nodeValue:sub(cursor)
    end
    return processedValue
end

function formatResolvedRecord(recordName, nodeType)
    local parsedRecordVar = parsedVariables[recordName]
    local recordType = LibraryData.getRecordTypeFromRecordPath(parsedRecordVar["resolvedVarValue"])
    local resolvedVarValue = parsedRecordVar["resolvedVarValue"]
    if recordType ~= "" and resolvedVarValue ~= "" then
        return "||" .. recordType .. "|" .. resolvedVarValue .. "|" .. recordName .. "||"
    else
        return recordName
    end
end

function parseNodes(recordNode)
    for _, nodeDef in ipairs(DB.getChildList(recordNode, "record_rows")) do
        parseNode(nodeDef, "")
    end
end

function parseNode(nodeDef, baseName)
    local name = DB.getValue(nodeDef, "name", "")
    if name == "" then
        name = DB.getName(nodeDef)
    end
    if baseName ~= "" then
        name = baseName .. "." .. name
    end
    local nodeType = DB.getValue(nodeDef, "nodeType", "")
    local nodeValue = ""
    if nodeType == "intermediate" then
        innerNodeValue = {}
        for _, innerNode in pairs(DB.getChildren(nodeDef, "sub_record_rows")) do
            parseNode(innerNode, name)
        end
        nodeValue = innerNodeValue
    elseif nodeType ~= "" then
        if nodeType == "formattedtext" then
            nodeValue = DB.getValue(nodeDef, "nodeFmtValue", "")
        else
            nodeValue = DB.getValue(nodeDef, "nodeValue", "")
        end
        local parsedNode = {
            ["nodeName"] = name,
            ["nodeType"] = nodeType,
            ["nodeValue"] = nodeValue
        }
        table.insert(parsedNodes, parsedNode)
    end
end

function parseVariables(recordNode)
    for _, varNode in ipairs(DB.getChildList(recordNode, "variable_rows")) do
        local varName = DB.getValue(varNode, "variableName", "")
        local varType = DB.getValue(varNode, "variableType", "")
        if varType ~= "" and (varSourceMap[varType] or "") ~= "" then
            local varValue = DB.getValue(varNode, varSourceMap[varType], "")
            parsedVariables[varName] = {
                ["varType"] = varType,
                ["varValue"] = varValue
            }
        end
    end
end

function resolveVariables()
    for varName, varDef in pairs(parsedVariables) do
        varDef["resolvedVarValue"] = parseCustomVariable(varDef["varType"], varDef["varValue"])
        parsedVariables[varName] = varDef
    end
end

local exGroupMatch = "%s*([^,]+)"

function parseCustomVariable(varType, varValue)
    if varType == "Exclusive Group" then
        local values = {}
        for varElem in varValue:gmatch(exGroupMatch) do
            table.insert(values, varElem)
        end
        return {
            ["allVals"] = values,
            ["availVals"] = values
        }
    elseif varType == "Record Type" then
        local record = getRecordOfType(varValue)
        if record and record.getNodeName then
            return record.getNodeName()
        else
            return ""
        end
    end
    return ""
end

function getAllFromModules(path)
    local nodes = {}
    if (path or "") == "" then return nodes end
    for name, node in pairs(DB.getChildren(path)) do
        table.insert(nodes, node)
    end
    for _, module in ipairs(Module.getModules()) do
        for name, node in pairs(DB.getChildren(path .. "@" .. module)) do
            table.insert(nodes, node)
        end
    end
    return nodes
end

function mergeTables(t1, t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function getRecordOfType(sourceRecordType)
    local records = {}
    if sourceRecordType:find(";") then
        for path in sourceRecordType:gmatch("([^;]+)") do
            records = mergeTables(records, getAllFromModules(path))
        end
    else
        for _, path in ipairs(LibraryData.getMappings(sourceRecordType)) do
            records = mergeTables(records, getAllFromModules(path))
        end
    end
    if #records == 0 then
        records = getAllFromModules(sourceRecordType)
    end
    if #records >= 1 then
        return records[math.random(#records)]
    else
        return ""
    end
end

function getExclusiveGroupVal(varName)
    local availVals = parsedVariables[varName]["resolvedVarValue"]["availVals"]
    if #availVals == 0 then
        availVals = parsedVariables[varName]["resolvedVarValue"]["allVals"]
    end
    if #availVals == 0 then
        return ""
    end
    local idx = math.random(#availVals)
    local randomVal = availVals[idx]
    table.remove(availVals, idx)
    parsedVariables[varName]["resolvedVarValue"]["availVals"] = availVals
    return randomVal
end

function resolveTemplateBody(bodyText)
    local nodesTable = {}
    local varsTable = {}
    local processedText = processText(bodyText)
    local sanitizedText = sanitizeProcessedText(processedText)
    for _, parsedTable in ipairs(Utility.decodeXML(sanitizedText)) do
        for _, row in ipairs(parsedTable) do
            if row and #row== 3 then
                local rName = row[1][1]
                local rType = row[2][1]
                local rValue = row[3][1]
                if parsedTable["name"] == "nodes" then
                    table.insert(nodesTable, {
                        ["nodeName"] = rName,
                        ["nodeType"] = rType,
                        ["nodeValue"] = rValue
                    })
                elseif parsedTable["name"] == "vars" then
                    varsTable[rName] = {
                        ["varType"] = rType,
                        ["varValue"] = rValue
                    }
                end
            end
        end
    end
    return nodesTable, varsTable
end

function getTemplateResBody()
    return '<nodes>' .. getNodeRows() .. "</nodes>" .. '<vars>' .. getVarRows() .. "</vars>"
end

function getNodeRows()
    local rowsTxt = ""
    for _, nodeDef in ipairs(parsedNodes) do
        local nodeName = nodeDef["nodeName"]
        local nodeType = nodeDef["nodeType"]
        local nodeValue = nodeDef["nodeValue"]
        rowsTxt = rowsTxt .. "<tr><td>" .. nodeName .. "</td><td>" .. nodeType .. "</td><td>" .. escapeXml(nodeValue) .. "</td></tr>"
    end
    return rowsTxt
end

function getVarRows()
    local rowsTxt = ""
    for varName, varDef in pairs(parsedVariables) do
        local varType = varDef["varType"]
        local varValue = varDef["varValue"]
        rowsTxt = rowsTxt .. "<tr><td>" .. varName .. "</td><td>" .. varType .. "</td><td>" .. escapeXml(varValue) .. "</td></tr>"
    end
    return rowsTxt
end

local sanitationPattern = '()<td>(.-)</td>()'

function sanitizeProcessedText(processedText)
    local sanitizedText = ""
    local cursor = 1
    for sIdx, processedVal, eIdx in processedText:gmatch(sanitationPattern) do
        sanitizedText = sanitizedText .. processedText:sub(cursor, sIdx-1) .. "<td>" .. escapeXml(processedVal) .. '</td>'
        cursor = eIdx
    end
    sanitizedText = sanitizedText .. processedText:sub(cursor)
    return sanitizedText
end

function escapeXml(strVal)
    strVal = strVal:gsub('&', '&amp;')
    strVal = strVal:gsub('<', '&#60;')
    strVal = strVal:gsub('>', '&#62;')
    strVal = strVal:gsub('""', '&quot;')
    strVal = strVal:gsub("''", '&apos;')
    return strVal
end

function unEscapeXml(strVal)
    strVal = strVal:gsub('&amp;', '&')
    strVal = strVal:gsub('&#60;', '<')
    strVal = strVal:gsub('&#62;', '>')
    strVal = strVal:gsub('&quot;', '""')
    strVal = strVal:gsub('&apos;', "''")
    return strVal
end

-- This is imitating the functionality in story_template_generate.lua, at some point might be good to go through
-- and figure out if all of these duplicate calls are really necessary. Regardless, there doesn't seem to be much performance impact

function processText(varText)
    local w = Interface.openWindow("storytemplate", "")
    varText = w.generate.CrossTemplateWrite(varText)
    varText = w.generate.performCalloutStorageReferences(varText)
    varText = w.generate.performInternalCallouts(varText)
    varText = w.generate.performInternalReferences(varText)
    varText = w.generate.performTableLookups(varText)
    varText = w.generate.CrossTemplateWrite(varText)
    varText = w.generate.performCalloutStorageReferences(varText)
    varText = w.generate.performColumnReferenceLinks(varText)
    varText = w.generate.performLiteralReplacements(varText)
    varText = w.generate.resolveInternalReferences(varText)
    varText = w.generate.performCalloutStorageReferences(varText)
    varText = w.generate.performCalloutStorageReferences(varText)
    varText = w.generate.performIndefiniteArticles(varText)
    varText = w.generate.performCapitalize(varText)
    varText = w.generate.performCalloutStorageReferences(varText)
    w.close()
    return varText
end