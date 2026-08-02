local QALog = {}

local function redact(text)
	text = string.gsub(text, "([Cc]:\\[Uu]sers\\)[^\\%s]+", "%1<redacted>")
	text = string.gsub(text, "[%w%._%+%-]+@[%w%.%-]+%.[%a]+", "<redacted-email>")
	text = string.gsub(text, "([Tt]oken%s*[=:]%s*)[^%s]+", "%1<redacted>")
	return text
end

function QALog.Safe(value, maxLength)
	local text = tostring(value == nil and "none" or value)
	text = string.gsub(text, "[%c|]", " ")
	text = redact(text)
	return string.sub(text, 1, maxLength or 200)
end

function QALog.FormatClientError(sourceName, message, stackTrace)
	return string.format(
		"[QA][Client] error | script=%s | message=%s | stack=%s",
		QALog.Safe(sourceName or "unknown", 120),
		QALog.Safe(message, 200),
		QALog.Safe(stackTrace, 500)
	)
end

return table.freeze(QALog)
