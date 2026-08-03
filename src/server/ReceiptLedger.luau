local ReceiptLedger = {}

local function ensureTables(profile)
	profile.ProcessedReceipts = if typeof(profile.ProcessedReceipts) == "table" then profile.ProcessedReceipts else {}
	profile.ReceiptOrder = if typeof(profile.ReceiptOrder) == "table" then profile.ReceiptOrder else {}
end

function ReceiptLedger.Has(profile, receiptId)
	ensureTables(profile)
	return profile.ProcessedReceipts[tostring(receiptId)] == true
end

function ReceiptLedger.Grant(profile, receiptId, shardAmount)
	ensureTables(profile)
	receiptId = tostring(receiptId)
	if profile.ProcessedReceipts[receiptId] then
		return false
	end

	profile.Shards += shardAmount
	profile.Stats.RobuxPurchases += 1
	profile.Stats.PurchasedShards += shardAmount
	profile.ProcessedReceipts[receiptId] = true
	table.insert(profile.ReceiptOrder, receiptId)
	return true
end

function ReceiptLedger.MergeHistory(target, source)
	ensureTables(target)
	ensureTables(source)

	local ordered = {}
	for _, receiptId in ipairs(target.ReceiptOrder) do
		ordered[receiptId] = true
	end

	for receiptId, processed in pairs(source.ProcessedReceipts) do
		if processed == true then
			target.ProcessedReceipts[receiptId] = true
			if not ordered[receiptId] then
				table.insert(target.ReceiptOrder, receiptId)
				ordered[receiptId] = true
			end
		end
	end
end

return ReceiptLedger
