new_aRecords = {
	["record_template"] = {
		bExport = true,
		bHidden = true,
		aDataMap = { "record_template", "reference.record_template" }
	},
}

function onInit()
    if User.isHost() then
        for kRecordType,vRecordType in pairs(new_aRecords) do
            LibraryData.setRecordTypeInfo(kRecordType, vRecordType);
        end
        LibraryData.addIndexButton("story", "button_record_template")
        LibraryData.addIndexButton("story", "button_inspect_record")
    end
end