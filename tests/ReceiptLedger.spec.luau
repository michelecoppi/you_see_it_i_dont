local Spec = {}

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function profile()
	return {
		Shards = 10,
		ProcessedReceipts = {},
		ReceiptOrder = {},
		Stats = {
			RobuxPurchases = 0,
			PurchasedShards = 0,
		},
	}
end

function Spec.run(ReceiptLedger)
	local current = profile()
	expect(ReceiptLedger.Grant(current, "purchase-1", 25), "the first receipt must grant shards")
	expect(current.Shards == 35, "the first receipt granted the wrong shard balance")
	expect(not ReceiptLedger.Grant(current, "purchase-1", 25), "a retry must not grant shards twice")
	expect(current.Shards == 35, "a retry changed the shard balance")
	expect(current.Stats.RobuxPurchases == 1, "a retry changed the purchase counter")

	for index = 2, 125 do
		expect(ReceiptLedger.Grant(current, "purchase-" .. tostring(index), 1), "a new receipt was rejected")
	end
	expect(ReceiptLedger.Has(current, "purchase-1"), "old receipts must remain idempotent after long histories")
	expect(not ReceiptLedger.Grant(current, "purchase-1", 25), "an old retry must not grant shards twice")

	local reconnected = profile()
	ReceiptLedger.MergeHistory(reconnected, current)
	expect(ReceiptLedger.Has(reconnected, "purchase-1"), "receipt history must survive profile reconciliation")
	expect(not ReceiptLedger.Grant(reconnected, "purchase-1", 25), "a reconnect retry must not grant shards twice")
end

return Spec
