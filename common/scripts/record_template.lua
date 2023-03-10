function onInit()
    onLockChanged()
end

function onLockChanged()
    if header.subwindow then
        header.subwindow.update()
    end
    if nodes.subwindow then
        nodes.subwindow.update()
    end
    if variables.subwindow then
        variables.subwindow.update()
    end
end
--
-- function setHeaderLock(bReadOnly)
--     header.subwindow.name.setReadOnly(bReadOnly)
--     header.subwindow.record_type.setReadOnly(bReadOnly)
--     header.subwindow.record_name_field.setReadOnly(bReadOnly)
-- end
--
-- function setNodesLock(bReadOnly)
--     if (nodes.subwindow or "") == "" then
--         return
--     end
--     nodes.setReadOnly(bReadOnly)
-- --     nodes.subwindow.record_rows.setReadOnly(locked)
-- --     for _, w in ipairs(nodes.subwindow.record_rows.getWindows()) do
-- --         w.setReadOnly(locked)
-- --     end
-- end