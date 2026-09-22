--[[
    Vynixu Entity Spawner V2
    Fixed + Jumpscare
]]--

if getgenv().VynixuEntitySpawnerV2 then
	return getgenv().VynixuEntitySpawnerV2
end

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

-- \\ Services // --

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

-- \\ Variables // --

local ROOT = "https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character.PrimaryPart or Character:FindFirstChildWhichIsA("BasePart", true)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("RemotesFolder")
local GameStats = ReplicatedStorage:WaitForChild("GameStats")
local CurrentRooms = workspace:WaitForChild("CurrentRooms")

local Assets = {
	Repentance = LoadCustomInstance(ROOT .. "/Assets/Repentance.rbxm"),
	Earthquake = LoadCustomInstance(ROOT .. "/Assets/Earthquake.rbxm")
}

local Modules = {
	Module_Events = require(ReplicatedStorage.ModulesClient.Module_Events),
	Main_Game = require(PlayerGui.MainUI.Initiator.Main_Game)
}

local Storage = {
	Ambient = {},

	DeathTypes = {
		["Yellow"] = {"yellow", "curious"},
		["Blue"] = {"blue", "guiding"}
	},

	CrucifixTypes = {
		["guiding"] = {
			Color = Color3.fromRGB(137, 207, 255)
		},

		["curious"] = {
			Color = Color3.fromRGB(255, 227, 137)
		}
	}
}

local CONST = {
	BASE_ENTITY_SPEED = 65,

	ATTR = {
		ENTITY = {
			Running = false,
			CustomEntity = true,
			Paused = false,
			BeingBanished = false,
			Despawning = false,
			Damage = true,
			LastEnteredRoom = -1
		},

		PLAYER = {
			SpawnProtection = 5
		}
	},

	DEFAULT = {
		CONFIG = {
			Entity = {
				Name = "Template Entity",

				Asset = "https://github.com/RegularVynixu/Utilities/raw/refs/heads/main/Doors/Entity%20Spawner/Assets/Entities/Rush.rbxm",

				HeightOffset = 0
			},

			Movement = {
				Speed = 100,
				Delay = 2,
				Reversed = false
			},

			Damage = {
				Enabled = true,
				Range = 40,
				Amount = 125,
				IgnoreHiding = false
			},

			-- \\ Jumpscare // --

			Jumpscare = {
				true,

				{
					Image1 = "rbxassetid://11417375410",
					Image2 = "rbxassetid://11417375410",

					Shake = true,

					Sound1 = {
						10483790459,
						{
							Volume = 0.5
						}
					},

					Sound2 = {
						5263560566,
						{
							Volume = 0.5
						}
					},

					Flashing = {
						true,
						Color3.fromRGB(50, 115, 108)
					},

					Tease = {
						false,
						Min = 1,
						Max = 5
					}
				}
			},

			Rebounding = {
				Enabled = true,
				Type = "Ambush",
				Min = 2,
				Max = 4,
				Delay = 2
			},

			Lights = {
				Flicker = {
					Enabled = true,
					Duration = 1
				},

				Shatter = true,
				Repair = false
			},

			Earthquake = {
				Enabled = true
			},

			CameraShake = {
				Enabled = true,
				Values = {1.5, 20, 0.1, 1},
				Range = 100
			},

			Crucifixion = {
				Type = "Guiding",
				Enabled = true,
				Range = 40,
				Resist = false,
				Break = true
			},

			Death = {
				Type = "Guiding",
				Hints = {"Death", "Hints", "Go", "Here"},
				Cause = ""
			}
		},

		DEBUG = {
			OnSpawned = function() end,
			OnStartMoving = function() end,
			OnReachedNode = function() end,
			OnEnterRoom = function() end,
			OnLookAt = function() end,
			OnRebounding = function() end,
			OnDespawning = function() end,
			OnDespawned = function() end,
			OnDamagePlayer = function() end,
			CrucifixionOverwrite = nil
		}
	}
}

local Module = {
	ActiveEntities = {},
	Connections = {}
}

-- \\ Functions // --

-- FIX: safely clone nil/non-table values
local function CloneTable(tbl)
	if typeof(tbl) ~= "table" then
		return tbl
	end

	local new = {}

	for key, value in next, tbl do
		if typeof(value) == "table" then
			new[key] = CloneTable(value)
		else
			new[key] = value
		end
	end

	return new
end

-- FIX: safely apply defaults when config or nested values are missing
local function ApplyConfigDefaults(tbl, defaults)
	if typeof(tbl) ~= "table" then
		tbl = {}
	end

	if typeof(defaults) ~= "table" then
		return CloneTable(tbl)
	end

	local new = CloneTable(tbl)

	for key, value in next, defaults do
		if new[key] == nil then
			new[key] = CloneTable(value)

		elseif typeof(value) == "table" then
			if typeof(new[key]) ~= "table" then
				new[key] = {}
			end

			new[key] = ApplyConfigDefaults(
				new[key],
				value
			)
		end
	end

	return new
end

local function OnCharacterAdded(char)
	LastRespawn = tick()

	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	RootPart = char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart")

	Modules.Main_Game = require(
		PlayerGui:WaitForChild("MainUI").Initiator.Main_Game
	)
end

local function GetCurrentRoom(latest)
	if latest then
		local rooms = CurrentRooms:GetChildren()
		return rooms[#rooms]
	end

	return CurrentRooms:FindFirstChild(
		LocalPlayer:GetAttribute("CurrentRoom")
	)
end

local function GetRoomAtPoint(vector3)
	local whitelist = {}

	for _, room in next, CurrentRooms:GetChildren() do
		local p = room:FindFirstChild(room.Name)

		if p then
			whitelist[#whitelist + 1] = p
		end
	end

	if #whitelist > 0 then
		local params = RaycastParams.new()

		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = whitelist
		params.CollisionGroup = "BaseCheck"

		local result = workspace:Raycast(
			vector3,
			Vector3.new(0, -100, 0),
			params
		)

		if result then
			for _, room in next, CurrentRooms:GetChildren() do
				if result.Instance.Parent == room then
					return room
				end
			end
		end
	end

	return nil
end

local function FixRoomLights(room)
	local roomEntrance = room:FindFirstChild("RoomEntrance")

	if not roomEntrance then
		return
	end

	for _, c in next, Camera:GetChildren() do
		if c.Name == "Piece" then
			c:Destroy()
		end
	end

	Modules.Module_Events.toggle(
		room,
		true,
		Storage.Ambient[room]
	)

	local stuff = {}

	for _, d in next, room:GetDescendants() do
		if d:IsA("Model") and
			(d.Name == "LightStand" or d.Name == "Chandelier") then

			table.insert(stuff, d)
		end
	end

	local random = Random.new(tick())

	for _, v in next, stuff do
		if v:GetAttribute("Shattered") then
			local r1 = random:NextInteger(-10, 10) / 50
			local r2 = random:NextInteger(5, 20) / 100

			task.delay(
				(roomEntrance.Position - v.PrimaryPart.Position).Magnitude / 150 + r1,
				function()

					local neon = v:FindFirstChild("Neon", true)

					for _, d in next, v:GetDescendants() do
						if d:IsA("Light") then
							TweenService:Create(
								d,
								TweenInfo.new(
									r2,
									Enum.EasingStyle.Quad,
									Enum.EasingDirection.InOut
								),
								{
									Brightness = d:GetAttribute("OGBrightness")
								}
							):Play()

						elseif d:IsA("Sound") then
							TweenService:Create(
								d,
								TweenInfo.new(
									r2,
									Enum.EasingStyle.Quad,
									Enum.EasingDirection.InOut
								),
								{
									Volume = d:GetAttribute("OGVolume")
								}
							):Play()
						end
					end

					if neon then
						neon.Transparency = 0.9
						neon.Material = Enum.Material.Neon

						TweenService:Create(
							neon,
							TweenInfo.new(
								r2,
								Enum.EasingStyle.Quart,
								Enum.EasingDirection.InOut
							),
							{
								Transparency = 0.2
							}
						):Play()

						task.wait(r2)
					end

					v:SetAttribute("Shattered", nil)
				end
			)
		end
	end
end

local function HasEquipped(name)
	local tool = Character:FindFirstChildOfClass("Tool")

	if tool and (tool.Name == name or tool:HasTag(name)) then
		return true, tool
	end

	return false
end

-- \\ Jumpscare // --

local function PlayJumpscare(config)
	if typeof(config) ~= "table" or config[1] ~= true then
		return
	end

	local s = config[2]

	if typeof(s) ~= "table" then
		return
	end

	-- Remove any previous jumpscare
	local oldGui = CoreGui:FindFirstChild("JumpscareGui")

	if oldGui then
		oldGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")

	gui.Name = "JumpscareGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.Parent = CoreGui

	local bg = Instance.new("Frame")

	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local face = Instance.new("ImageLabel")

	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(150, 150)
	face.BackgroundTransparency = 1
	face.ImageTransparency = 0
	face.ResampleMode = Enum.ResamplerMode.Pixelated

	-- Image 1
	if typeof(s.Image1) == "string" then
		pcall(function()
			face.Image = LoadCustomAsset(s.Image1)
		end)
	end

	face.Parent = gui

	local function LoadSound(data)
		if typeof(data) ~= "table" then
			return nil
		end

		if data[1] == nil then
			return nil
		end

		local sound = Instance.new("Sound")

		sound.SoundId =
			"rbxassetid://" .. tostring(data[1])

		for property, value in pairs(data[2] or {}) do
			pcall(function()
				sound[property] = value
			end)
		end

		sound.Parent = SoundService

		return sound
	end

	local sound1 = LoadSound(s.Sound1)
	local sound2 = LoadSound(s.Sound2)

	-- \\ Tease // --

	if typeof(s.Tease) == "table" and s.Tease[1] == true then
		local min = tonumber(s.Tease.Min) or 1
		local max = tonumber(s.Tease.Max) or 5

		min = math.max(1, min)
		max = math.max(min, max)

		for i = 1, math.random(min, max) do

			if sound1 then
				sound1:Play()
			end

			task.wait(
				math.random(100, 200) / 100
			)

			local size = 150 + i * 75

			face.Size = UDim2.fromOffset(
				size,
				size
			)
		end
	end

	-- \\ Flashing // --

	local flashThread

	if typeof(s.Flashing) == "table"
		and s.Flashing[1] == true then

		flashThread = task.spawn(function()
			while gui.Parent do
				bg.BackgroundColor3 =
					s.Flashing[2]
					or Color3.new(1, 1, 1)

				task.wait(
					math.random(25, 100) / 1000
				)

				if not gui.Parent then
					break
				end

				bg.BackgroundColor3 =
					Color3.new(0, 0, 0)

				task.wait(
					math.random(25, 100) / 1000
				)
			end
		end)
	end

	-- \\ Shake // --

	local shakeConnection

	if s.Shake == true then
		shakeConnection =
			RunService.RenderStepped:Connect(function()

				if not face.Parent then
					return
				end

				face.Position = UDim2.new(
					0.5,
					math.random(-35, 35),
					0.5,
					math.random(-10, 10)
				)

				face.Rotation =
					math.random(-5, 5)
			end)
	end

	-- \\ Image 2 + Sound 2 // --

	if typeof(s.Image2) == "string" then
		pcall(function()
			face.Image = LoadCustomAsset(s.Image2)
		end)
	end

	if sound2 then
		sound2:Play()
	end

	-- \\ Zoom // --

	local camera = workspace.CurrentCamera

	local zoomSize =
		(camera and camera.ViewportSize.Y or 1080) * 3

	local zoomTween = TweenService:Create(
		face,

		TweenInfo.new(
			1.5,
			Enum.EasingStyle.Linear
		),

		{
			Size = UDim2.fromOffset(
				zoomSize,
				zoomSize
			),

			ImageTransparency = 0
		}
	)

	zoomTween:Play()

	task.wait(1.5)

	-- \\ Cleanup // --

	if shakeConnection then
		shakeConnection:Disconnect()
	end

	if flashThread then
		task.cancel(flashThread)
	end

	if sound1 then
		sound1:Destroy()
	end

	if sound2 then
		sound2:Destroy()
	end

	if gui then
		gui:Destroy()
	end
end

local function CrucifixEntity(entity)
	local model = entity.Model
	local config = entity.Config

	local resist = config.Crucifixion.Resist

	local entityPivot = model:GetPivot()

	local params = RaycastParams.new()

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		Character,
		model
	}

	local result = workspace:Raycast(
		entityPivot.Position,
		Vector3.new(0, -1000, 0),
		params
	)

	if not result then
		return
	end

	model:SetAttribute("BeingBanished", true)

	local MainGame =
		require(PlayerGui.MainUI.Initiator.Main_Game)

	local CamShaker = MainGame.camShaker

	local TheShake =
		CamShaker:StartShake(
			5,
			20,
			2,
			Vector3.zero
		)

	local Repentance = Assets.Repentance:Clone()
	local Crucifix = Repentance.Crucifix
	local Handle = Crucifix.Handle
	local Pentagram = Repentance.Pentagram
	local EntityPart = Repentance.Entity
	local Sound = Handle[resist and "SoundFail" or "Sound"]

	Repentance:PivotTo(
		CFrame.new(result.Position)
	)

	Crucifix:PivotTo(
		Character:GetPivot()
	)

	EntityPart.CFrame = entityPivot
	Repentance.Parent = workspace
	Sound:Play()

	local function waitUntil(t)
		repeat
			RunService.RenderStepped:Wait()
		until Sound.TimePosition >= t
	end

	local function fadeOut()
		for _, v in Pentagram:GetChildren() do
			if v.Name == "BeamFlat" then
				task.delay(
					v:GetAttribute("Delay") or 0,
					function()

						TweenService:Create(
							v,
							TweenInfo.new(
								1.5,
								Enum.EasingStyle.Sine,
								Enum.EasingDirection.In
							),
							{
								Brightness = 0
							}
						):Play()
					end
				)

			elseif v.Name == "BeamChain" then
				TweenService:Create(
					v,
					TweenInfo.new(
						1.5,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.In
					),
					{
						Brightness = 0
					}
				):Play()
			end
		end
	end

	local crucifixType =
		config.Crucifixion.Type:lower()

	local crucifixData =
		Storage.CrucifixTypes[crucifixType]

	local Color =
		crucifixData and crucifixData.Color
		or Color3.fromRGB(137, 207, 255)

	for _, v in next, Repentance:QueryDescendants(".GiveMeColor") do
		if v:IsA("Light") or v:IsA("BasePart") then
			v.Color = Color

		elseif v:IsA("ParticleEmitter") or v:IsA("Beam") then
			v.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color),
				ColorSequenceKeypoint.new(1, Color)
			})
		end
	end

	task.spawn(function()
		if not resist then
			while EntityPart.Parent do
				model:PivotTo(EntityPart.CFrame)
				RunService.RenderStepped:Wait()
			end

			model:Destroy()
		end
	end)

	TweenService:Create(
		Pentagram.Circle,
		TweenInfo.new(
			2,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		),
		{
			CFrame =
				Pentagram.Circle.CFrame
				- Vector3.new(0, 25, 0)
		}
	):Play()

	task.delay(
		2,
		Pentagram.Circle.Destroy,
		Pentagram.Circle
	)

	Handle.BodyPosition.Position =
		(Character:GetPivot() * CFrame.new(1, 4, -6)).Position

	TweenService:Create(
		Handle.BodyAngularVelocity,
		TweenInfo.new(
			4,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.In
		),
		{
			AngularVelocity = Vector3.new(0, 40, 0)
		}
	):Play()

	task.delay(3, function()
		for _, shard in next, Handle.Shards:GetChildren() do
			shard.CollisionGroup = "NoPlayer"
			shard.CanCollide = true
			shard.Weld:Destroy()
			shard.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	if not resist then
		TweenService:Create(
			EntityPart,
			TweenInfo.new(
				3,
				Enum.EasingStyle.Elastic,
				Enum.EasingDirection.In
			),
			{
				CFrame =
					EntityPart.CFrame
					+ Vector3.new(0, 2, 0)
			}
		):Play()
	end

	task.spawn(function()
		waitUntil(2.625)

		TweenService:Create(
			Pentagram.Base.LightAttach.LightBright,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 5,
				Range = 40
			}
		):Play()

		TweenService:Create(
			Handle.Light,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 11.25,
				Range = 30
			}
		):Play()

		task.wait(1.5)

		TweenService:Create(
			Pentagram.Base.LightAttach.LightBright,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 0,
				Range = 0
			}
		):Play()

		TweenService:Create(
			Handle.Light,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 0,
				Range = 0
			}
		):Play()

		if not resist then
			TweenService:Create(
				Handle.Light,
				TweenInfo.new(
					1,
					Enum.EasingStyle.Circular,
					Enum.EasingDirection.InOut
				),
				{
					Brightness = 15,
					Range = 40
				}
			):Play()

			TheShake:StartFadeOut(3)

			fadeOut()

			TweenService:Create(
				Handle.BodyAngularVelocity,
				TweenInfo.new(
					3,
					Enum.EasingStyle.Cubic,
					Enum.EasingDirection.Out
				),
				{
					AngularVelocity = Vector3.zero
				}
			):Play()
		end
	end)

	if not resist then
		waitUntil(2.5)

		TweenService:Create(
			EntityPart,
			TweenInfo.new(
				3,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.In
			),
			{
				CFrame =
					EntityPart.CFrame
					- Vector3.new(0, 50, 0)
			}
		):Play()

		for _, s in next, model:QueryDescendants("Sound") do
			if s:GetAttribute("VolumeIgnore") then
				continue
			end

			TweenService:Create(
				s,
				TweenInfo.new(
					3,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.In
				),
				{
					Volume = 0
				}
			):Play()
		end

		waitUntil(6.75)
	else
		waitUntil(4)

		TweenService:Create(
			Handle.BodyAngularVelocity,
			TweenInfo.new(
				3,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				AngularVelocity = Vector3.zero
			}
		):Play()

		TweenService:Create(
			Pentagram.Base.LightAttach.LightBright,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 0,
				Range = 0,
				Color = Color3.fromRGB(255, 116, 130)
			}
		):Play()

		TweenService:Create(
			Handle.Light,
			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.InOut
			),
			{
				Brightness = 0,
				Range = 0,
				Color = Color3.fromRGB(255, 116, 130)
			}
		):Play()

		TheShake:StartFadeOut(3)

		task.spawn(function()
			local color = Instance.new("Color3Value")

			color.Value =
				Color3.fromRGB(137, 207, 255)

			local tween = TweenService:Create(
				color,
				TweenInfo.new(
					0.5,
					Enum.EasingStyle.Sine
				),
				{
					Value = Color3.fromRGB(255, 116, 130)
				}
			)

			tween:Play()

			while tween.PlaybackState ==
				Enum.PlaybackState.Playing do

				for _, d in next, Repentance:GetDescendants() do
					if d.ClassName == "Beam" then
						d.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(
								0,
								color.Value
							),
							ColorSequenceKeypoint.new(
								1,
								color.Value
							)
						})

					elseif d.Name == "Glow" then
						d.Color = color.Value
					end
				end

				task.wait()
			end

			color:Destroy()
		end)

		waitUntil(9.625)
	end

	TweenService:Create(
		Handle.Glow,
		TweenInfo.new(1),
		{
			Size = Handle.Glow.Size * 3,
			Transparency = 1
		}
	):Play()

	TweenService:Create(
		Pentagram.Base.LightAttach.LightBright,
		TweenInfo.new(1),
		{
			Brightness = 0,
			Range = 0
		}
	):Play()

	TweenService:Create(
		Handle.Light,
		TweenInfo.new(1),
		{
			Brightness = 0,
			Range = 0
		}
	):Play()

	if not resist then
		Handle.ExplodeParticle:Emit(
			math.random(20, 30)
		)

		CamShaker:ShakeOnce(
			7.5,
			7.5,
			0.25,
			1.5
		)
	else
		model:SetAttribute("BeingBanished", false)
		model:SetAttribute("Paused", false)

		fadeOut()
	end

	task.delay(
		5,
		Repentance.Destroy,
		Repentance
	)
end

local function IsPlayerProtected()
	return (
		tick() - LastRespawn
	) <= LocalPlayer:GetAttribute("SpawnProtection")
end

local function DamagePlayer(entity)
	if Humanoid.Health <= 0 or IsPlayerProtected() then
		return
	end

	local config = entity.Config

	local newHealth = math.clamp(
		Humanoid.Health - config.Damage.Amount,
		0,
		Humanoid.MaxHealth
	)

	Humanoid.Health = newHealth

	task.spawn(
		entity.RunCallback,
		entity,
		"OnDamagePlayer",
		newHealth
	)

	if newHealth == 0 then

		-- \\ Jumpscare // --

		task.spawn(function()
			PlayJumpscare(config.Jumpscare)
		end)

		-- Death hints --

		if #config.Death.Hints > 0 then
			PlayerGui.MainUI.Death:GetPropertyChangedSignal(
				"Visible"
			):Wait()

			local colour

			for name, values in next, Storage.DeathTypes do
				if table.find(
					values,
					config.Death.Type:lower()
				) then
					colour = name
				end
			end

			if not colour then
				for _, c in next,
					PlayerGui.MainUI.Initiator.Main_Game.Health.Music:GetChildren() do

					if c.Name:lower() ==
						config.Death.Type:lower() then

						colour = c.Name
					end
				end
			end

			if not colour then
				colour = "Blue"
			end

			if firesignal then
				firesignal(
					Remotes.DeathHint.OnClientEvent,
					config.Death.Hints,
					colour
				)
			else
				warn(
					debug.traceback(
						"function 'firesignal' not supported by exploit, ignoring death hints"
					)
				)
			end
		end

		local cause = config.Death.Cause

		if typeof(cause) ~= "string" or cause == "" then
			cause = config.Entity.Name
		end

		local playerStats =
			GameStats:FindFirstChild(
				"Player_" .. LocalPlayer.Name
			)

		if playerStats
			and playerStats:FindFirstChild("Total")
			and playerStats.Total:FindFirstChild("DeathCause") then

			playerStats.Total.DeathCause.Value = cause
		end
	end
end

local function GetNodesFromRoom(room, reversed)
	local nodes = {}

	local roomEntrance =
		room:FindFirstChild("RoomEntrance")

	if roomEntrance then
		local n = roomEntrance:Clone()

		n.Name = "0"
		n.CFrame -= Vector3.new(0, 3, 0)

		nodes[1] = n
	end

	local nodesFolder =
		room:FindFirstChild("PathfindNodes")

	if nodesFolder then
		for _, n in next, nodesFolder:GetChildren() do
			nodes[#nodes + 1] = n
		end
	end

	local roomExit =
		room:FindFirstChild("RoomExit")

	if roomExit then
		local index = #nodes + 1

		local n = roomExit:Clone()

		n.Name = tostring(index)
		n.CFrame -= Vector3.new(0, 3, 0)

		nodes[index] = n
	end

	table.sort(nodes, function(a, b)
		local aName = tonumber(a.Name) or 0
		local bName = tonumber(b.Name) or 0

		if reversed then
			return aName > bName
		end

		return aName < bName
	end)

	return nodes
end

local function GetPathfindNodesAmbush(config)
	local pathfindNodes = {}
	local rooms = CurrentRooms:GetChildren()

	if config.Movement.Reversed == false then
		for i = 1, #rooms do
			local room = rooms[i]
			local roomNodes =
				GetNodesFromRoom(room, false)

			for _, node in next, roomNodes do
				pathfindNodes[#pathfindNodes + 1] = node
			end
		end
	else
		for i = #rooms, 1, -1 do
			local room = rooms[i]
			local roomNodes =
				GetNodesFromRoom(room, true)

			for _, node in next, roomNodes do
				pathfindNodes[#pathfindNodes + 1] = node
			end
		end
	end

	return pathfindNodes
end

local function GetPathfindNodesBlitz(config)
	local nodesToCurrent = {}
	local nodesToEnd = {}

	local currentRoomIndex =
		LocalPlayer:GetAttribute("CurrentRoom")

	local rooms = CurrentRooms:GetChildren()

	if config.Movement.Reversed == false then
		for _, room in next, rooms do
			local roomNodes =
				GetNodesFromRoom(room, false)

			local roomIndex =
				tonumber(room.Name)

			for _, node in next, roomNodes do
				if roomIndex <= currentRoomIndex then
					nodesToCurrent[#nodesToCurrent + 1] = node
				else
					nodesToEnd[#nodesToEnd + 1] = node
				end
			end
		end
	else
		for i = #rooms, 1, -1 do
			local room = rooms[i]

			local roomNodes =
				GetNodesFromRoom(room, true)

			local roomIndex =
				tonumber(room.Name)

			for _, node in next, roomNodes do
				if roomIndex >= currentRoomIndex then
					nodesToCurrent[#nodesToCurrent + 1] = node
				else
					nodesToEnd[#nodesToEnd + 1] = node
				end
			end
		end
	end

	return nodesToCurrent, nodesToEnd
end

local function EntityMoveTo(model, cframe, speed)
	local reached = false
	local connection

	connection = RunService.Stepped:Connect(
		function(_, step)

			if not model:GetAttribute("Paused") then
				local pivot = model:GetPivot()

				local difference =
					cframe.Position - pivot.Position

				local magnitude = difference.Magnitude

				if magnitude > 0.1 then
					local unit = difference.Unit

					model:PivotTo(
						pivot +
						unit *
						math.min(
							step * speed,
							magnitude
						)
					)
				else
					connection:Disconnect()
					reached = true
				end
			end
		end
	)

	repeat
		RunService.Stepped:Wait()
	until reached
end

local function Earthquake()
	Modules.Main_Game.camShaker:ShakeOnce(
		4,
		12,
		1,
		5
	)

	Modules.Main_Game.camShaker:ShakeOnce(
		10,
		2,
		3,
		3
	)

	Assets.Earthquake.SoundEarthquake:Play()

	local v5 =
		CollectionService:GetTagged("PartCeiling")

	local v6 = {}

	for _, v7 in v5 do
		local v8 = v7.Size.Magnitude * 0.7
		local v9 = math.clamp(v8, 0, 150)

		for _, v10 in
			Assets.Earthquake.Particles:GetChildren() do

			local v11 = v10:Clone()

			v11.Parent = v7
			v11:Emit(v9 / 10)
			v11.Enabled = true

			table.insert(v6, v11)
		end
	end

	task.wait(4)

	for _, v12 in v6 do
		v12.Enabled = false
	end
end

-- \\ Setup // --

for name, value in next, CONST.ATTR.PLAYER do
	LocalPlayer:SetAttribute(name, value)
end

LastRespawn =
	tick() -
	LocalPlayer:GetAttribute("SpawnProtection")

LocalPlayer.CharacterAdded:Connect(
	OnCharacterAdded
)

-- \\ Main // --

Module.Create = function(self, config)
	-- FIX: allow nil/non-table configs
	if typeof(config) ~= "table" then
		config = {}
	end

	local newConfig =
		ApplyConfigDefaults(
			config,
			CONST.DEFAULT.CONFIG
		)

	-- FIX: use merged config instead of raw config
	newConfig.Movement.Speed =
		CONST.BASE_ENTITY_SPEED / 100 *
		(tonumber(newConfig.Movement.Speed) or 100)

	local asset = newConfig.Entity.Asset

	local success
	local entityModel

	if typeof(asset) == "Instance" then
		success = true
		entityModel = asset

	elseif typeof(asset) == "string" then
		success, entityModel = pcall(function()

			local instance =
				LoadCustomInstance(asset)

			if typeof(instance) == "Instance" then
				if instance.ClassName ~= "Model" then
					error(
						"Entity model Instance invalid, expected Model"
					)
				end
			else
				error(
					"Failed to fetch entity model."
				)
			end

			return instance
		end)
	end

	if not (success and entityModel) then
		return
	end

	local rootPart =
		entityModel.PrimaryPart or
		entityModel:FindFirstChildWhichIsA(
			"BasePart",
			true
		)

	if not rootPart then
		return
	end

	rootPart.Anchored = true
	entityModel.PrimaryPart = rootPart

	local name = newConfig.Entity.Name

	if typeof(name) == "string" and name ~= "" then
		entityModel.Name = name
	end

	for attr, val in next, CONST.ATTR.ENTITY do
		entityModel:SetAttribute(attr, val)
	end

	local c = Instance.new("Configuration")

	c.Name = "RoomsEntered"
	c.Parent = entityModel

	return {
		Model = entityModel,

		Config = newConfig,

		Debug = CloneTable(
			CONST.DEFAULT.DEBUG
		),

		SetCallback = function(self, key, callback)
			assert(
				typeof(key) == "string" and self.Debug[key] ~= nil,
				"Callback key is invalid."
			)

			assert(
				typeof(callback) == "function",
				"Callback must be a function."
			)

			self.Debug[key] = callback
		end,

		RunCallback = function(self, key, ...)
			local callback = self.Debug[key]

			if typeof(callback) == "function" then
				local success, result =
					pcall(callback, ...)

				if not success then
					warn(result)
				end
			end
		end,

		IsAlive = function(self)
			return self.Model and self.Model.Parent
		end,

		Pause = function(self)
			if self:IsAlive() then
				self.Model:SetAttribute(
					"Paused",
					true
				)
			end
		end,

		Resume = function(self)
			if self:IsAlive() then
				self.Model:SetAttribute(
					"Paused",
					false
				)
			end
		end,

		Run = function(self, copyEntity)
			Module:Run(
				self,
				copyEntity
			)
		end,

		Despawn = function(self)
			if self:IsAlive() then
				self.Model:Destroy()

				local i =
					table.find(
						Module.ActiveEntities,
						self
					)

				if i then
					table.remove(
						Module.ActiveEntities,
						i
					)
				end

				task.spawn(
					self.RunCallback,
					self,
					"OnDespawned"
				)
			end
		end
	}
end

Module.Run = function(self, entity, copyEntity)
	if copyEntity == true then
		self:Run(
			CloneTable(entity),
			false
		)

		return
	end

	if not entity or not entity.Model then
		return
	end

	if entity.Model:GetAttribute("Running") then
		return
	end

	do
		local rebounding =
			entity.Config.Rebounding

		if
			rebounding.Enabled
			and (
				rebounding.Min <= 0
				or rebounding.Max <= 0
				or rebounding.Min > rebounding.Max
			)
		then
			error(
				string.format(
					"Invalid rebounding minmax values: %s - %s",
					rebounding.Min,
					rebounding.Max
				)
			)
		end
	end

	local model = entity.Model
	local config = entity.Config
	local debug = entity.Debug

	model:SetAttribute("Running", true)

	self.ActiveEntities[
		#self.ActiveEntities + 1
	] = entity

	local spawnPoint

	do
		local rooms =
			CurrentRooms:GetChildren()

		if config.Movement.Reversed then
			spawnPoint =
				rooms[#rooms]:FindFirstChild(
					"RoomExit"
				)
		else
			spawnPoint =
				rooms[1]:FindFirstChild(
					"RoomEntrance"
				)
		end
	end

	if not spawnPoint then
		error(
			"Failed to find spawn point for entity: "
			.. config.Entity.Name
		)
	end

	model:PivotTo(
		spawnPoint.CFrame +
		Vector3.new(
			0,
			config.Entity.HeightOffset,
			0
		)
	)

	model.Parent = workspace

	task.spawn(
		entity.RunCallback,
		entity,
		"OnSpawned"
	)

	local currentRoom =
		GetCurrentRoom(false)

	if currentRoom then
		if config.Lights.Flicker.Enabled then
			Modules.Module_Events.flicker(
				currentRoom,
				config.Lights.Flicker.Duration
			)
		end

		if config.Earthquake.Enabled then
			task.spawn(Earthquake)
		end
	end

	task.wait(
		config.Movement.Delay
	)

	task.spawn(
		entity.RunCallback,
		entity,
		"OnStartMoving"
	)

	task.spawn(function()
		while entity:IsAlive() and task.wait() do
			if model:GetAttribute("Paused") then
				continue
			end

			if not RootPart or not RootPart.Parent then
				break
			end

			local origin =
				model:GetPivot().Position

			local charOrigin =
				RootPart.Position

			local inSight = false

			if
				(charOrigin - origin).Magnitude
				<= config.Damage.Range
			then
				local params =
					RaycastParams.new()

				params.FilterType =
					Enum.RaycastFilterType.Exclude

				params.FilterDescendantsInstances = {
					Character,
					model,
					CollectionService:GetTagged(
						"HidingSpot"
					)
				}

				inSight =
					workspace:Raycast(
						origin,
						charOrigin - origin,
						params
					) == nil
			end

			if Humanoid.Health > 0 then
				local _, isVisible =
					Camera:WorldToViewportPoint(
						origin
					)

				if isVisible then
					task.spawn(
						entity.RunCallback,
						entity,
						"OnLookAt",
						inSight
					)
				end
			end

			do
				local room =
					GetRoomAtPoint(origin)

				if room then
					local index =
						tonumber(room.Name)

					if
						index
						and index >= 0
						and index ~=
							model:GetAttribute(
								"LastEnteredRoom"
							)
					then
						model:SetAttribute(
							"LastEnteredRoom",
							index
						)

						local roomsEntered =
							model:FindFirstChild(
								"RoomsEntered"
							)

						if roomsEntered then
							local firstTime =
								roomsEntered:GetAttribute(
									room.Name
								) == nil

							task.spawn(
								entity.RunCallback,
								entity,
								"OnEnterRoom",
								room,
								firstTime
							)

							if firstTime then
								roomsEntered:SetAttribute(
									room.Name,
									true
								)
							end

							local latestRoom =
								GetCurrentRoom(true)

							if room ~= latestRoom then
								if config.Lights.Shatter then
									Modules.Module_Events.shatter(
										room
									)
								elseif config.Lights.Repair then
									FixRoomLights(room)
								end
							end
						end
					end
				end
			end

			local usedCrucifix = false

			do
				local crucifixion =
					config.Crucifixion

				if
					crucifixion.Enabled
					and crucifixion.Range > 0
					and (charOrigin - origin).Magnitude
						<= crucifixion.Range
					and inSight
				then
					local hasTool, tool =
						HasEquipped("Crucifix")

					if
						hasTool
						and tool
						and not model:GetAttribute(
							"BeingBanished"
						)
					then

						if typeof(
							debug.CrucifixionOverwrite
						) == "function" then

							entity:RunCallback(
								"CrucifixionOverwrite"
							)
						else
							tool:Destroy()

							model:SetAttribute(
								"Paused",
								true
							)

							CrucifixEntity(entity)
						end

						usedCrucifix = true
					end
				end
			end

			if
				not model:GetAttribute("Paused")
				and not usedCrucifix
			then
				local damage =
					config.Damage

				if
					damage.Enabled
					and damage.Range > 0
					and Humanoid.Health > 0
					and (
						not Character:GetAttribute(
							"Hiding"
						)
						or damage.IgnoreHiding
					)
					and model:GetAttribute("Damage")
					and not model:GetAttribute(
						"BeingBanished"
					)
					and (charOrigin - origin).Magnitude
						<= damage.Range
					and inSight
				then
					model:SetAttribute(
						"Damage",
						false
					)

					DamagePlayer(entity)
				end
			end

			do
				local camShake =
					config.CameraShake

				if camShake.Enabled then
					local mag =
						(charOrigin - origin).Magnitude

					if mag <= camShake.Range then
						local cloned = {}

						for i, v in next,
							camShake.Values do

							cloned[i] = v
						end

						cloned[1] =
							camShake.Values[1]
							/ camShake.Range
							* (camShake.Range - mag)

						cloned[2] =
							camShake.Values[2]
							/ camShake.Range
							* (camShake.Range - mag)

						Modules.Main_Game.camShaker:ShakeOnce(
							table.unpack(cloned)
						)
					end
				end
			end
		end
	end)

	task.spawn(function()
		local reboundType =
			config.Rebounding.Type:upper()

		if reboundType == "AMBUSH" then
			local pathfindNodes =
				GetPathfindNodesAmbush(config)

			for _, v in next,
				pathfindNodes do

				local cframe =
					v.CFrame +
					Vector3.new(
						0,
						3 +
							config.Entity.HeightOffset,
						0
					)

				EntityMoveTo(
					model,
					cframe,
					config.Movement.Speed
				)

				task.spawn(
					entity.RunCallback,
					entity,
					"OnReachNode",
					v
				)
			end

			if config.Rebounding.Enabled then
				local reboundsCount =
					math.random(
						config.Rebounding.Min,
						config.Rebounding.Max
					)

				for i = 1,
					reboundsCount do

					task.wait(
						config.Rebounding.Delay
					)

					model:SetAttribute(
						"Damage",
						true
					)

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						true
					)

					for i = #pathfindNodes,
						1,
						-1 do

						local v =
							pathfindNodes[i]

						local cframe =
							v.CFrame +
							Vector3.new(
								0,
								3 +
									config.Entity.HeightOffset,
								0
							)

						EntityMoveTo(
							model,
							cframe,
							config.Movement.Speed
						)

						task.spawn(
							entity.RunCallback,
							entity,
							"OnReachNode",
							v
						)
					end

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						false
					)

					task.wait(
						config.Rebounding.Delay
					)

					model:SetAttribute(
						"Damage",
						true
					)

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						true
					)

					pathfindNodes =
						GetPathfindNodesAmbush(
							config
						)

					for _, v in next,
						pathfindNodes do

						local cframe =
							v.CFrame +
							Vector3.new(
								0,
								3 +
									config.Entity.HeightOffset,
								0
							)

						EntityMoveTo(
							model,
							cframe,
							config.Movement.Speed
						)

						task.spawn(
							entity.RunCallback,
							entity,
							"OnReachNode",
							v
						)
					end

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						false
					)

					if i < reboundsCount then
						task.wait(
							config.Rebounding.Delay
						)
					end
				end
			end

		elseif reboundType == "BLITZ" then
			local nodesToCurrent =
				GetPathfindNodesBlitz(config)

			for _, n in next,
				nodesToCurrent do

				local cframe =
					n.CFrame +
					Vector3.new(
						0,
						3 +
							config.Entity.HeightOffset,
						0
					)

				EntityMoveTo(
					model,
					cframe,
					config.Movement.Speed
				)

				task.spawn(
					entity.RunCallback,
					entity,
					"OnReachNode",
					n
				)
			end

			if config.Rebounding.Enabled then
				local currentRoom =
					GetCurrentRoom(false)

				if not currentRoom then
					return
				end

				local roomNodes =
					GetNodesFromRoom(
						currentRoom,
						config.Movement.Reversed
					)

				if #roomNodes == 1 then
					return
				end

				local randomNode

				if config.Movement.Reversed == false then
					randomNode =
						roomNodes[
							math.random(
								1,
								#roomNodes - 1
							)
						]
				else
					randomNode =
						roomNodes[
							math.random(
								2,
								#roomNodes
							)
						]
				end

				if not randomNode then
					return
				end

				for _ = 1,
					math.random(
						config.Rebounding.Min,
						config.Rebounding.Max
					) do

					model:SetAttribute(
						"Damage",
						true
					)

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						true
					)

					local nodeIndex =
						tonumber(
							randomNode.Name
						)

					for i = #roomNodes,
						nodeIndex,
						-1 do

						local cframe =
							roomNodes[
								math.clamp(
									i,
									1,
									#roomNodes
								)
							].CFrame +
							Vector3.new(
								0,
								3 +
									config.Entity.HeightOffset,
								0
							)

						EntityMoveTo(
							model,
							cframe,
							config.Movement.Speed
						)

						task.spawn(
							entity.RunCallback,
							entity,
							"OnReachNode",
							roomNodes[i]
						)
					end

					task.wait(
						config.Rebounding.Delay
					)

					model:SetAttribute(
						"Damage",
						true
					)

					task.spawn(
						entity.RunCallback,
						entity,
						"OnRebounding",
						false
					)

					for i = nodeIndex,
						#roomNodes do

						local cframe =
							roomNodes[
								math.clamp(
									i,
									1,
									#roomNodes
								)
							].CFrame +
							Vector3.new(
								0,
								3 +
									config.Entity.HeightOffset,
								0
							)

						EntityMoveTo(
							model,
							cframe,
							config.Movement.Speed
						)

						task.spawn(
							entity.RunCallback,
							entity,
							"OnReachNode",
							roomNodes[i]
						)
					end
				end
			end

			local _, updatedToEnd =
				GetPathfindNodesBlitz(config)

			for _, n in next,
				updatedToEnd do

				local cframe =
					n.CFrame +
					Vector3.new(
						0,
						3 +
							config.Entity.HeightOffset,
						0
					)

				EntityMoveTo(
					model,
					cframe,
					config.Movement.Speed
				)

				task.spawn(
					entity.RunCallback,
					entity,
					"OnReachNode",
					n
				)
			end
		end

		if not model:GetAttribute("Despawning") then
			model:SetAttribute(
				"Despawning",
				true
			)

			task.spawn(
				entity.RunCallback,
				entity,
				"OnDespawning"
			)

			EntityMoveTo(
				model,
				model:GetPivot() -
					Vector3.new(0, 300, 0),
				config.Movement.Speed
			)

			entity:Despawn()
		end
	end)
end

-- \\ Internal setup // --

if not getgenv()._internal_vynixu_entity_spawner then
	getgenv()._internal_vynixu_entity_spawner = true

	local function GetAmbient(room)
		return
			room:GetAttribute("AmbientOriginal")
			or room:GetAttribute("Ambient")
			or Color3.fromRGB(67, 51, 56)
	end

	for _, room in next,
		CurrentRooms:GetChildren() do

		Storage.Ambient[room] =
			GetAmbient(room)
	end

	local roomConnection =
		CurrentRooms.ChildAdded:Connect(
			function(room)
				Storage.Ambient[room] =
					GetAmbient(room)
			end
		)

	table.insert(
		Module.Connections,
		roomConnection
	)

	local removeConnection =
		workspace.DescendantRemoving:Connect(
			function(instance)

				if instance.Name == "PathfindNodes" then
					local latestRoom =
						GetCurrentRoom(true)

					if latestRoom then
						instance:Clone().Parent =
							latestRoom
					end
				end
			end
		)

	table.insert(
		Module.Connections,
		removeConnection
	)
end

Module.Clear = function(self)
	for _, entity in next,
		self.ActiveEntities do

		entity:Despawn()
	end

	table.clear(self.ActiveEntities)
end

Module.Unload = function(self)
	self:Clear()

	for i, connection in next,
		self.Connections do

		if connection then
			connection:Disconnect()
		end

		self.Connections[i] = nil
	end

	for i in next, self do
		self[i] = nil
	end
end

getgenv().VynixuEntitySpawnerV2 = Module

return Module