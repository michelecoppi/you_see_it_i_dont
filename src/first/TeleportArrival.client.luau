-- Runs from ReplicatedFirst so the transition screen carried over by TeleportService stays up
-- while the expedition (or hub) server loads, then fades out once the game is ready.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local arriving = TeleportService:GetArrivingTeleportGui()
if not arriving then
	return
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
arriving.Enabled = true
arriving.ResetOnSpawn = false
arriving.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local background = arriving:FindFirstChild("Background")
local ring = background and background:FindFirstChild("Ring")
local subtitle = background and background:FindFirstChild("Subtitle")
if subtitle and subtitle:IsA("TextLabel") then
	subtitle.Text = "Synchronizing realities..."
end

local spinning = true
task.spawn(function()
	while spinning and ring and ring.Parent do
		ring.Rotation = (ring.Rotation + 4) % 360
		task.wait(1 / 30)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(1.5)

local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
if background and background:IsA("Frame") then
	TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
	for _, descendant in ipairs(background:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, info, { TextTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
end
task.wait(0.7)
spinning = false
arriving:Destroy()
