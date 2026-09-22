--[[
	Vynixu Entity Spawner V2
	Fixed + Jumpscare
]]

if getgenv().VynixuEntitySpawnerV2 then
	return getgenv().VynixuEntitySpawnerV2
end

loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"
))()

-- \\ Services // --

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

-- \\ Variables // --

local ROOT =
	"https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"

local LocalPlayer = Players.LocalPlayer

local Character =
	LocalPlayer.Character
	or LocalPlayer.CharacterAdded:Wait()

local Humanoid =
	Character:WaitForChild("Humanoid")

local RootPart =
	Character:FindFirstChild("HumanoidRootPart")
	or Character.PrimaryPart
	or Character:FindFirstChildWhichIsA("BasePart", true)

local PlayerGui =
	LocalPlayer:WaitForChild("PlayerGui")

local Camera =
	workspace.CurrentCamera

local Remotes =
	ReplicatedStorage:WaitForChild("RemotesFolder")

local GameStats =
	ReplicatedStorage:WaitForChild("GameStats")

local CurrentRooms =
	workspace:WaitForChild("CurrentRooms")

local Assets = {
	Repentance =
		LoadCustomInstance(
			ROOT .. "/Assets/Repentance.rbxm"
		),

	Earthquake =
		LoadCustomInstance(
			ROOT .. "/Assets/Earthquake.rbxm"
		)
}

local Modules = {
	Module_Events =
		require(
			ReplicatedStorage.ModulesClient.Module_Events
		),

	Main_Game =
		require(
			PlayerGui.MainUI.Initiator.Main_Game
		)
}

local Storage = {
	Ambient = {},

	DeathTypes = {
		["Yellow"] = {
			"yellow",
			"curious"
		},

		["Blue"] = {
			"blue",
			"guiding"
		}
	},

	CrucifixTypes = {
		["guiding"] = {
			Color =
				Color3.fromRGB(
					137,
					207,
					255
				)
		},

		["curious"] = {
			Color =
				Color3.fromRGB(
					255,
					227,
					137
				)
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

				-- No default entity.
				-- Every entity must provide its own Asset.
				Asset = nil,

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
					Image1 =
						"rbxassetid://11417375410",

					Image2 =
						"rbxassetid://11417375410",

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

						Color3.fromRGB(
							50,
							115,
							108
						)
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
				Values = {
					1.5,
					20,
					0.1,
					1
				},
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
				Hints = {
					"Death",
					"Hints",
					"Go",
					"Here"
				},
				Cause = ""
			}
		},

		DEBUG = {
			OnSpawned =
				function()
				end,

			OnStartMoving =
				function()
				end,

			OnReachedNode =
				function()
				end,

			OnEnterRoom =
				function()
				end,

			OnLookAt =
				function()
				end,

			OnRebounding =
				function()
				end,

			OnDespawning =
				function()
				end,

			OnDespawned =
				function()
				end,

			OnDamagePlayer =
				function()
				end,

			CrucifixionOverwrite = nil
		}
	}
}

local Module = {
	ActiveEntities = {},
	Connections = {}
}

-- \\ Utility // --

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

local function ApplyConfigDefaults(tbl, defaults)
	if typeof(tbl) ~= "table" then
		tbl = {}
	end

	if typeof(defaults) ~= "table" then
		return CloneTable(tbl)
	end

	local new =
		CloneTable(tbl)

	for key, value in next, defaults do

		-- Never insert nil defaults.
		-- This prevents Entity.Asset from
		-- being accidentally processed as nil.

		if new[key] == nil then

			if value ~= nil then
				new[key] =
					CloneTable(value)
			end

		elseif typeof(value) == "table" then

			if typeof(new[key]) ~= "table" then
				new[key] = {}
			end

			new[key] =
				ApplyConfigDefaults(
					new[key],
					value
				)
		end
	end

	return new
end

local function NormalizeConfig(config)

	if typeof(config) ~= "table" then
		error(
			"Entity configuration must be a table."
		)
	end

	local newConfig =
		ApplyConfigDefaults(
			config,
			CONST.DEFAULT.CONFIG
		)

	-- Entity

	if typeof(newConfig.Entity) ~= "table" then
		newConfig.Entity = {}
	end

	if typeof(newConfig.Entity.Name) ~= "string"
		or newConfig.Entity.Name == ""
	then

		newConfig.Entity.Name =
			"Template Entity"
	end

	-- DO NOT FALL BACK TO RUSH.
	-- Entity.Asset must explicitly be supplied.

	local entityAsset =
		newConfig.Entity.Asset

	if typeof(entityAsset) ~= "string"
		and typeof(entityAsset) ~= "Instance"
	then

		error(
			"Entity.Asset is required for '"
			.. tostring(newConfig.Entity.Name)
			.. "'. No default entity will be used."
		)
	end

	if typeof(entityAsset) == "string"
		and entityAsset == ""
	then

		error(
			"Entity.Asset cannot be empty for '"
			.. tostring(newConfig.Entity.Name)
			.. "'."
		)
	end

	if typeof(entityAsset) == "Instance"
		and not entityAsset:IsA("Model")
	then

		error(
			"Entity.Asset must be a Model for '"
			.. tostring(newConfig.Entity.Name)
			.. "'."
		)
	end

	newConfig.Entity.HeightOffset =
		tonumber(
			newConfig.Entity.HeightOffset
		)
		or 0

	-- Movement

	newConfig.Movement.Speed =
		tonumber(
			newConfig.Movement.Speed
		)
		or 100

	newConfig.Movement.Delay =
		math.max(
			0,
			tonumber(
				newConfig.Movement.Delay
			)
			or 0
		)

	newConfig.Movement.Reversed =
		newConfig.Movement.Reversed == true

	-- Damage

	newConfig.Damage.Enabled =
		newConfig.Damage.Enabled == true

	newConfig.Damage.Range =
		math.max(
			0,
			tonumber(
				newConfig.Damage.Range
			)
			or 40
		)

	newConfig.Damage.Amount =
		math.max(
			0,
			tonumber(
				newConfig.Damage.Amount
			)
			or 125
		)

	newConfig.Damage.IgnoreHiding =
		newConfig.Damage.IgnoreHiding == true

	-- Rebounding

	newConfig.Rebounding.Enabled =
		newConfig.Rebounding.Enabled == true

	newConfig.Rebounding.Type =
		typeof(newConfig.Rebounding.Type) == "string"
		and newConfig.Rebounding.Type
		or "Ambush"

	newConfig.Rebounding.Min =
		math.max(
			1,
			math.floor(
				tonumber(
					newConfig.Rebounding.Min
				)
				or 1
			)
		)

	newConfig.Rebounding.Max =
		math.max(
			newConfig.Rebounding.Min,
			math.floor(
				tonumber(
					newConfig.Rebounding.Max
				)
				or newConfig.Rebounding.Min
			)
		)

	newConfig.Rebounding.Delay =
		math.max(
			0,
			tonumber(
				newConfig.Rebounding.Delay
			)
			or 2
		)

	-- Lights

	newConfig.Lights.Flicker.Enabled =
		newConfig.Lights.Flicker.Enabled == true

	newConfig.Lights.Flicker.Duration =
		math.max(
			0,
			tonumber(
				newConfig.Lights.Flicker.Duration
			)
			or 1
		)

	newConfig.Lights.Shatter =
		newConfig.Lights.Shatter == true

	newConfig.Lights.Repair =
		newConfig.Lights.Repair == true

	-- Earthquake

	newConfig.Earthquake.Enabled =
		newConfig.Earthquake.Enabled == true

	-- Camera shake

	newConfig.CameraShake.Enabled =
		newConfig.CameraShake.Enabled == true

	newConfig.CameraShake.Range =
		math.max(
			0.001,
			tonumber(
				newConfig.CameraShake.Range
			)
			or 100
		)

	if typeof(newConfig.CameraShake.Values) ~= "table" then
		newConfig.CameraShake.Values =
			CloneTable(
				CONST.DEFAULT.CONFIG.CameraShake.Values
			)
	end

	for i = 1, 4 do
		newConfig.CameraShake.Values[i] =
			tonumber(
				newConfig.CameraShake.Values[i]
			)
			or CONST.DEFAULT.CONFIG.CameraShake.Values[i]
	end

	-- Jumpscare

	if typeof(newConfig.Jumpscare) ~= "table" then
		newConfig.Jumpscare =
			CloneTable(
				CONST.DEFAULT.CONFIG.Jumpscare
			)
	end

	newConfig.Jumpscare[1] =
		newConfig.Jumpscare[1] == true

	if typeof(newConfig.Jumpscare[2]) ~= "table" then
		newConfig.Jumpscare[2] =
			CloneTable(
				CONST.DEFAULT.CONFIG.Jumpscare[2]
			)
	end

	local jumpscare =
		newConfig.Jumpscare[2]

	jumpscare.Shake =
		jumpscare.Shake == true

	if typeof(jumpscare.Flashing) ~= "table" then
		jumpscare.Flashing =
			CloneTable(
				CONST.DEFAULT.CONFIG.Jumpscare[2].Flashing
			)
	end

	if typeof(jumpscare.Tease) ~= "table" then
		jumpscare.Tease =
			CloneTable(
				CONST.DEFAULT.CONFIG.Jumpscare[2].Tease
			)
	end

	jumpscare.Flashing[1] =
		jumpscare.Flashing[1] == true

	jumpscare.Tease[1] =
		jumpscare.Tease[1] == true

	jumpscare.Tease.Min =
		math.max(
			1,
			math.floor(
				tonumber(
					jumpscare.Tease.Min
				)
				or 1
			)
		)

	jumpscare.Tease.Max =
		math.max(
			jumpscare.Tease.Min,
			math.floor(
				tonumber(
					jumpscare.Tease.Max
				)
				or 5
			)
		)

	-- Crucifixion

	newConfig.Crucifixion.Type =
		typeof(newConfig.Crucifixion.Type) == "string"
		and newConfig.Crucifixion.Type
		or "Guiding"

	newConfig.Crucifixion.Enabled =
		newConfig.Crucifixion.Enabled == true

	newConfig.Crucifixion.Range =
		math.max(
			0,
			tonumber(
				newConfig.Crucifixion.Range
			)
			or 40
		)

	newConfig.Crucifixion.Resist =
		newConfig.Crucifixion.Resist == true

	newConfig.Crucifixion.Break =
		newConfig.Crucifixion.Break == true

	-- Death

	newConfig.Death.Type =
		typeof(newConfig.Death.Type) == "string"
		and newConfig.Death.Type
		or "Guiding"

	if typeof(newConfig.Death.Hints) ~= "table" then
		newConfig.Death.Hints = {}
	end

	if typeof(newConfig.Death.Cause) ~= "string" then
		newConfig.Death.Cause = ""
	end

	return newConfig
end

-- \\ Character // --

local function OnCharacterAdded(char)
	LastRespawn = tick()

	Character = char

	Humanoid =
		char:WaitForChild("Humanoid")

	RootPart =
		char:FindFirstChild("HumanoidRootPart")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA(
			"BasePart",
			true
		)

	Camera =
		workspace.CurrentCamera

	Modules.Main_Game =
		require(
			PlayerGui:WaitForChild("MainUI")
				.Initiator
				.Main_Game
		)
end

-- \\ Rooms // --

local function GetSortedRooms()
	local rooms =
		CurrentRooms:GetChildren()

	table.sort(
		rooms,
		function(a, b)
			return
				(
					tonumber(a.Name)
					or 0
				)
				<
				(
					tonumber(b.Name)
					or 0
				)
		end
	)

	return rooms
end

local function GetCurrentRoom(latest)
	local rooms =
		GetSortedRooms()

	if latest then
		return rooms[#rooms]
	end

	local currentRoom =
		tonumber(
			LocalPlayer:GetAttribute(
				"CurrentRoom"
			)
		)

	if currentRoom then
		return CurrentRooms:FindFirstChild(
			tostring(currentRoom)
		)
	end

	return nil
end

local function GetRoomAtPoint(vector3)
	local whitelist = {}

	for _, room in next, CurrentRooms:GetChildren() do
		local p =
			room:FindFirstChild(
				room.Name
			)

		if p then
			whitelist[#whitelist + 1] = p
		end
	end

	if #whitelist <= 0 then
		return nil
	end

	local params =
		RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Include

	params.FilterDescendantsInstances =
		whitelist

	params.CollisionGroup =
		"BaseCheck"

	local result =
		workspace:Raycast(
			vector3,
			Vector3.new(
				0,
				-100,
				0
			),
			params
		)

	if not result then
		return nil
	end

	for _, room in next,
		CurrentRooms:GetChildren() do

		if result.Instance:IsDescendantOf(room) then
			return room
		end
	end

	return nil
end

local function FixRoomLights(room)
	local roomEntrance =
		room:FindFirstChild("RoomEntrance")

	if not roomEntrance then
		return
	end

	if Camera then
		for _, c in next,
			Camera:GetChildren() do

			if c.Name == "Piece" then
				c:Destroy()
			end
		end
	end

	Modules.Module_Events.toggle(
		room,
		true,
		Storage.Ambient[room]
	)

	local stuff = {}

	for _, d in next,
		room:GetDescendants() do

		if d:IsA("Model")
			and (
				d.Name == "LightStand"
				or d.Name == "Chandelier"
			)
		then
			table.insert(
				stuff,
				d
			)
		end
	end

	local random =
		Random.new()

	for _, v in next, stuff do
		if v:GetAttribute("Shattered") then

			local primary =
				v.PrimaryPart

			if not primary then
				continue
			end

			local r1 =
				random:NextInteger(
					-10,
					10
				) / 50

			local r2 =
				random:NextInteger(
					5,
					20
				) / 100

			task.delay(
				(
					roomEntrance.Position
					- primary.Position
				).Magnitude / 150
				+ r1,

				function()

					if not v.Parent then
						return
					end

					local neon =
						v:FindFirstChild(
							"Neon",
							true
						)

					for _, d in next,
						v:GetDescendants() do

						if d:IsA("Light") then

							TweenService:Create(
								d,
								TweenInfo.new(
									r2,
									Enum.EasingStyle.Quad,
									Enum.EasingDirection.InOut
								),
								{
									Brightness =
										d:GetAttribute(
											"OGBrightness"
										)
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
									Volume =
										d:GetAttribute(
											"OGVolume"
										)
								}
							):Play()
						end
					end

					if neon then

						neon.Transparency = 0.9
						neon.Material =
							Enum.Material.Neon

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

					if v.Parent then
						v:SetAttribute(
							"Shattered",
							nil
						)
					end
				end
			)
		end
	end
end

-- \\ Tools // --

local function HasEquipped(name)
	if not Character then
		return false
	end

	local tool =
		Character:FindFirstChildOfClass(
			"Tool"
		)

	if tool
		and (
			tool.Name == name
			or tool:HasTag(name)
		)
	then
		return true, tool
	end

	return false
end

-- \\ Jumpscare // --

local JumpscarePlaying = false

local function PlayJumpscare(config)
	if JumpscarePlaying then
		return
	end

	if typeof(config) ~= "table"
		or config[1] ~= true
	then
		return
	end

	local s = config[2]

	if typeof(s) ~= "table" then
		return
	end

	JumpscarePlaying = true

	local oldGui = CoreGui:FindFirstChild("JumpscareGui")

	if oldGui then
		oldGui:Destroy()
	end

	local image1 = LoadCustomAsset(s.Image1)
	local image2 = LoadCustomAsset(s.Image2)

	local function LoadJumpscareSound(data)
		if typeof(data) ~= "table"
			or data[1] == nil
		then
			return nil
		end

		local sound = Instance.new("Sound")

		local soundId = tostring(data[1])

		if soundId:find("rbxasset://") then
			sound.SoundId = soundId
		else
			sound.SoundId =
				"rbxassetid://" ..
				soundId:gsub("%D", "")
		end

		if typeof(data[2]) == "table" then
			for property, value in next, data[2] do
				pcall(function()
					sound[property] = value
				end)
			end
		end

		sound.Parent = workspace

		return sound
	end

	local sound1 = LoadJumpscareSound(s.Sound1)
	local sound2 = LoadJumpscareSound(s.Sound2)

	local gui = Instance.new("ScreenGui")
	local bg = Instance.new("Frame")
	local face = Instance.new("ImageLabel")

	gui.Name = "JumpscareGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	bg.Name = "Background"
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.ZIndex = 999

	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.BackgroundTransparency = 1
	face.Position = UDim2.new(0.5, 0, 0.5, 0)
	face.Size = UDim2.new(0, 150, 0, 150)
	face.Image = image1 or ""
	face.ZIndex = 1000

	pcall(function()
		face.ResampleMode = Enum.ResamplerMode.Pixelated
	end)

	face.Parent = bg
	bg.Parent = gui
	gui.Parent = CoreGui

	local absHeight = gui.AbsoluteSize.Y
	local minTeaseSize = absHeight / 5
	local maxTeaseSize = absHeight / 2.5

	-- \\ Tease // --

	local teaseConfig = s.Tease

	if typeof(teaseConfig) == "table"
		and teaseConfig[1] == true
	then

		local min = math.max(
			1,
			math.floor(
				tonumber(teaseConfig.Min) or 1
			)
		)

		local max = math.max(
			min,
			math.floor(
				tonumber(teaseConfig.Max) or 5
			)
		)

		local teaseAmount = math.random(min, max)

		if sound1 then
			sound1:Play()
		end

		for _ = min, teaseAmount do
			task.wait(
				math.random(100, 200) / 100
			)

			local growFactor =
				(maxTeaseSize - minTeaseSize)
				/ teaseAmount

			face.Size = UDim2.new(
				0,
				face.AbsoluteSize.X + growFactor,
				0,
				face.AbsoluteSize.Y + growFactor
			)
		end

		task.wait(
			math.random(100, 200) / 100
		)
	end

	-- \\ Flashing // --

	if typeof(s.Flashing) == "table"
		and s.Flashing[1] == true
	then

		task.spawn(function()
			while gui.Parent do
				bg.BackgroundColor3 = s.Flashing[2]

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

	if s.Shake == true then
		task.spawn(function()
			local origin = face.Position

			while gui.Parent do
				face.Position =
					origin +
					UDim2.new(
						0,
						math.random(-10, 10),
						0,
						math.random(-10, 10)
					)

				face.Rotation =
					math.random(-5, 5)

				task.wait()
			end
		end)
	end

	-- \\ Image 2 + Sound 2 // --

	face.Image =
		image2 or image1 or ""

	face.Size =
		UDim2.new(
			0,
			maxTeaseSize,
			0,
			maxTeaseSize
		)

	if sound2 then
		sound2:Play()
	end

	-- \\ Zoom // --

	TS:Create(
		face,
		TweenInfo.new(0.75),
		{
			Size = UDim2.new(
				0,
				absHeight * 3,
				0,
				absHeight * 3
			),

			ImageTransparency = 0.5
		}
	):Play()

	task.wait(0.75)

	if gui then
		gui:Destroy()
	end

	if sound1 then
		sound1:Stop()
		sound1:Destroy()
	end

	if sound2 then
		sound2:Stop()
		sound2:Destroy()
	end
end

-- \\ Crucifix // --

local function CrucifixEntity(entity)
	local model =
		entity.Model

	local config =
		entity.Config

	local resist =
		config.Crucifixion.Resist

	if not model
		or not model.Parent
	then
		return
	end

	local entityPivot =
		model:GetPivot()

	local params =
		RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances = {
		Character,
		model
	}

	local result =
		workspace:Raycast(
			entityPivot.Position,
			Vector3.new(
				0,
				-1000,
				0
			),
			params
		)

	if not result then
		return
	end

	if not Assets.Repentance then

		model:SetAttribute(
			"BeingBanished",
			false
		)

		model:SetAttribute(
			"Paused",
			false
		)

		return
	end

	model:SetAttribute(
		"BeingBanished",
		true
	)

	local MainGame =
		require(
			PlayerGui.MainUI.Initiator.Main_Game
		)

	local CamShaker =
		MainGame.camShaker

	local TheShake =
		CamShaker:StartShake(
			5,
			20,
			2,
			Vector3.zero
		)

	local Repentance =
		Assets.Repentance:Clone()

	local Crucifix =
		Repentance.Crucifix

	local Handle =
		Crucifix.Handle

	local Pentagram =
		Repentance.Pentagram

	local EntityPart =
		Repentance.Entity

	local Sound =
		Handle[
			resist
			and "SoundFail"
			or "Sound"
		]

	if not Sound
		or not Sound:IsA("Sound")
	then

		Repentance:Destroy()

		model:SetAttribute(
			"BeingBanished",
			false
		)

		model:SetAttribute(
			"Paused",
			false
		)

		return
	end

	Repentance:PivotTo(
		CFrame.new(
			result.Position
		)
	)

	Crucifix:PivotTo(
		Character:GetPivot()
	)

	EntityPart.CFrame =
		entityPivot

	Repentance.Parent =
		workspace

	Sound:Play()

	local function waitUntil(t)
		local startTime =
			tick()

		repeat

			RunService.RenderStepped:Wait()

			if not Sound.Parent then
				break
			end

		until
			Sound.TimePosition >= t
			or tick() - startTime >= t + 1
	end

	local function fadeOut()

		if not Pentagram.Parent then
			return
		end

		for _, v in
			Pentagram:GetChildren() do

			if v.Name == "BeamFlat" then

				task.delay(
					v:GetAttribute(
						"Delay"
					)
					or 0,

					function()

						if not v.Parent then
							return
						end

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
		(
			config.Crucifixion.Type
			or "Guiding"
		):lower()

	local crucifixData =
		Storage.CrucifixTypes[
			crucifixType
		]

	local Color =
		crucifixData
		and crucifixData.Color
		or Color3.fromRGB(
			137,
			207,
			255
		)

	for _, v in next,
		Repentance:QueryDescendants(
			".GiveMeColor"
		) do

		if v:IsA("Light")
			or v:IsA("BasePart")
		then

			v.Color = Color

		elseif v:IsA("ParticleEmitter")
			or v:IsA("Beam")
		then

			v.Color =
				ColorSequence.new({
					ColorSequenceKeypoint.new(
						0,
						Color
					),

					ColorSequenceKeypoint.new(
						1,
						Color
					)
				})
		end
	end

	task.spawn(function()

		if not resist then

			while EntityPart.Parent
				and model.Parent do

				model:PivotTo(
					EntityPart.CFrame
				)

				RunService.RenderStepped:Wait()
			end

			if model.Parent then
				model:Destroy()
			end
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
				- Vector3.new(
					0,
					25,
					0
				)
		}
	):Play()

	task.delay(
		2,
		function()

			if Pentagram.Circle.Parent then
				Pentagram.Circle:Destroy()
			end
		end
	)

	Handle.BodyPosition.Position =
		(
			Character:GetPivot()
			* CFrame.new(
				1,
				4,
				-6
			)
		).Position

	TweenService:Create(
		Handle.BodyAngularVelocity,
		TweenInfo.new(
			4,
			Enum.EasingStyle.Cubic,
			Enum.EasingDirection.In
		),
		{
			AngularVelocity =
				Vector3.new(
					0,
					40,
					0
				)
		}
	):Play()

	task.delay(
		3,
		function()

			if not Handle.Parent then
				return
			end

			for _, shard in
				Handle.Shards:GetChildren() do

				shard.CollisionGroup =
					"NoPlayer"

				shard.CanCollide = true

				local weld =
					shard:FindFirstChild("Weld")

				if weld then
					weld:Destroy()
				end

				shard.AssemblyAngularVelocity =
					Vector3.zero
			end
		end
	)

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
					+ Vector3.new(
						0,
						2,
						0
					)
			}
		):Play()
	end

	task.spawn(function()

		waitUntil(2.625)

		if not Repentance.Parent then
			return
		end

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

		if not Repentance.Parent then
			return
		end

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
					AngularVelocity =
						Vector3.zero
				}
			):Play()
		end
	end)

	if not resist then

		waitUntil(2.5)

		if not Repentance.Parent then
			return
		end

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
					- Vector3.new(
						0,
						50,
						0
					)
			}
		):Play()

		for _, s in next,
			model:QueryDescendants(
				"Sound"
			) do

			if s:GetAttribute(
				"VolumeIgnore"
			) then
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

		if not Repentance.Parent then
			return
		end

		TweenService:Create(
			Handle.BodyAngularVelocity,
			TweenInfo.new(
				3,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			),
			{
				AngularVelocity =
					Vector3.zero
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

				Color =
					Color3.fromRGB(
						255,
						116,
						130
					)
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

				Color =
					Color3.fromRGB(
						255,
						116,
						130
					)
			}
		):Play()

		TheShake:StartFadeOut(3)

		task.spawn(function()

			local color =
				Instance.new(
					"Color3Value"
				)

			color.Value =
				Color3.fromRGB(
					137,
					207,
					255
				)

			local tween =
				TweenService:Create(
					color,
					TweenInfo.new(
						0.5,
						Enum.EasingStyle.Sine
					),
					{
						Value =
							Color3.fromRGB(
								255,
								116,
								130
							)
					}
				)

			tween:Play()

			while tween.PlaybackState ==
				Enum.PlaybackState.Playing
			do

				if not Repentance.Parent then
					break
				end

				for _, d in next,
					Repentance:GetDescendants() do

					if d.ClassName == "Beam" then

						d.Color =
							ColorSequence.new({
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
						d.Color =
							color.Value
					end
				end

				task.wait()
			end

			color:Destroy()
		end)

		waitUntil(9.625)
	end

	if not Repentance.Parent then
		return
	end

	TweenService:Create(
		Handle.Glow,
		TweenInfo.new(1),
		{
			Size =
				Handle.Glow.Size * 3,

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
			math.random(
				20,
				30
			)
		)

		CamShaker:ShakeOnce(
			7.5,
			7.5,
			0.25,
			1.5
		)

	else

		model:SetAttribute(
			"BeingBanished",
			false
		)

		model:SetAttribute(
			"Paused",
			false
		)

		fadeOut()
	end

	task.delay(
		5,
		function()

			if Repentance.Parent then
				Repentance:Destroy()
			end
		end
	)
end

-- \\ Damage // --

local function IsPlayerProtected()
	local spawnProtection =
		tonumber(
			LocalPlayer:GetAttribute(
				"SpawnProtection"
			)
		)
		or 5

	return
		(
			tick() - LastRespawn
		)
		<= spawnProtection
end

local function DamagePlayer(entity)

	if not Humanoid
		or Humanoid.Health <= 0
		or IsPlayerProtected()
	then
		return
	end

	local config =
		entity.Config

	local amount =
		math.max(
			0,
			tonumber(
				config.Damage.Amount
			)
			or 0
		)

	local newHealth =
		math.clamp(
			Humanoid.Health - amount,
			0,
			Humanoid.MaxHealth
		)

	Humanoid.Health =
		newHealth

	task.spawn(
		entity.RunCallback,
		entity,
		"OnDamagePlayer",
		newHealth
	)

	if newHealth ~= 0 then
	return
end

-- \\ Jumpscare // --

if not Humanoid:GetAttribute("VynixuJumpscarePlayed") then
	Humanoid:SetAttribute(
		"VynixuJumpscarePlayed",
		true
	)

	PlayJumpscare(config.Jumpscare)
end

-- \\ Death hints // --

	if #config.Death.Hints > 0 then

		local deathGui =
			PlayerGui.MainUI:FindFirstChild(
				"Death"
			)

		if deathGui then

			pcall(function()

				deathGui:GetPropertyChangedSignal(
					"Visible"
				):Wait()
			end)
		end

		local colour

		local deathType =
			(
				config.Death.Type
				or "Guiding"
			):lower()

		for name, values in
			next,
			Storage.DeathTypes do

			if table.find(
				values,
				deathType
			) then

				colour =
					name

				break
			end
		end

		if not colour then

			local mainGame =
				PlayerGui.MainUI.Initiator.Main_Game

			local health =
				mainGame:FindFirstChild(
					"Health"
				)

			local music =
				health
				and health:FindFirstChild(
					"Music"
				)

			if music then

				for _, c in next,
					music:GetChildren() do

					if c.Name:lower() ==
						deathType
					then

						colour =
							c.Name

						break
					end
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
				"function 'firesignal' not supported by exploit, ignoring death hints"
			)
		end
	end

	-- \\ Death cause // --

	local cause =
		config.Death.Cause

	if typeof(cause) ~= "string"
		or cause == ""
	then

		cause =
			config.Entity.Name
	end

	local playerStats =
		GameStats:FindFirstChild(
			"Player_" ..
			LocalPlayer.Name
		)

	if playerStats
		and playerStats:FindFirstChild(
			"Total"
		)
	then

		local total =
			playerStats.Total

		local deathCause =
			total:FindFirstChild(
				"DeathCause"
			)

		if deathCause then
			deathCause.Value =
				cause
		end
	end
end

-- \\ Pathfinding // --

local function GetNodesFromRoom(
	room,
	reversed
)
	local nodes = {}

	local roomEntrance =
		room:FindFirstChild(
			"RoomEntrance"
		)

	if roomEntrance then

		local n =
			roomEntrance:Clone()

		n.Name = "0"

		n.CFrame -=
			Vector3.new(
				0,
				3,
				0
			)

		nodes[1] = n
	end

	local nodesFolder =
		room:FindFirstChild(
			"PathfindNodes"
		)

	if nodesFolder then

		for _, n in next,
			nodesFolder:GetChildren() do

			nodes[#nodes + 1] =
				n
		end
	end

	local roomExit =
		room:FindFirstChild(
			"RoomExit"
		)

	if roomExit then

		local index =
			#nodes + 1

		local n =
			roomExit:Clone()

		n.Name =
			tostring(index)

		n.CFrame -=
			Vector3.new(
				0,
				3,
				0
			)

		nodes[index] = n
	end

	table.sort(
		nodes,
		function(a, b)

			local aName =
				tonumber(a.Name)
				or 0

			local bName =
				tonumber(b.Name)
				or 0

			if reversed then
				return aName > bName
			end

			return aName < bName
		end
	)

	return nodes
end

local function GetPathfindNodesAmbush(config)
	local pathfindNodes = {}

	local rooms =
		GetSortedRooms()

	if config.Movement.Reversed == false then

		for i = 1, #rooms do

			local room =
				rooms[i]

			local roomNodes =
				GetNodesFromRoom(
					room,
					false
				)

			for _, node in next,
				roomNodes do

				pathfindNodes[
					#pathfindNodes + 1
				] = node
			end
		end

	else

		for i = #rooms, 1, -1 do

			local room =
				rooms[i]

			local roomNodes =
				GetNodesFromRoom(
					room,
					true
				)

			for _, node in next,
				roomNodes do

				pathfindNodes[
					#pathfindNodes + 1
				] = node
			end
		end
	end

	return pathfindNodes
end

local function GetPathfindNodesBlitz(config)
	local nodesToCurrent = {}
	local nodesToEnd = {}

	local currentRoomIndex =
		tonumber(
			LocalPlayer:GetAttribute(
				"CurrentRoom"
			)
		)
		or 0

	local rooms =
		GetSortedRooms()

	if config.Movement.Reversed == false then

		for _, room in next,
			rooms do

			local roomNodes =
				GetNodesFromRoom(
					room,
					false
				)

			local roomIndex =
				tonumber(
					room.Name
				)
				or 0

			for _, node in next,
				roomNodes do

				if roomIndex <= currentRoomIndex then

					nodesToCurrent[
						#nodesToCurrent + 1
					] = node

				else

					nodesToEnd[
						#nodesToEnd + 1
					] = node
				end
			end
		end

	else

		for i = #rooms, 1, -1 do

			local room =
				rooms[i]

			local roomNodes =
				GetNodesFromRoom(
					room,
					true
				)

			local roomIndex =
				tonumber(
					room.Name
				)
				or 0

			for _, node in next,
				roomNodes do

				if roomIndex >= currentRoomIndex then

					nodesToCurrent[
						#nodesToCurrent + 1
					] = node

				else

					nodesToEnd[
						#nodesToEnd + 1
					] = node
				end
			end
		end
	end

	return nodesToCurrent, nodesToEnd
end

-- \\ Entity movement // --

local function EntityMoveTo(
	model,
	cframe,
	speed
)
	local reached = false
	local cancelled = false

	local connection

	connection =
		RunService.Stepped:Connect(
			function(_, step)

				if not model
					or not model.Parent
				then

					cancelled = true

					if connection then
						connection:Disconnect()
					end

					return
				end

				if model:GetAttribute(
					"Paused"
				) then
					return
				end

				local pivot =
					model:GetPivot()

				local difference =
					cframe.Position
					- pivot.Position

				local magnitude =
					difference.Magnitude

				if magnitude > 0.1 then

					local unit =
						difference.Unit

					model:PivotTo(
						pivot
						+
						unit
						*
						math.min(
							step * speed,
							magnitude
						)
					)

				else

					reached = true

					if connection then
						connection:Disconnect()
					end
				end
			end
		)

	repeat
		RunService.Stepped:Wait()
	until reached or cancelled

	return reached
end

-- \\ Earthquake // --

local function Earthquake()
	if not Assets.Earthquake then
		return
	end

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

	local earthquakeSound =
		Assets.Earthquake:FindFirstChild(
			"SoundEarthquake"
		)

	if earthquakeSound then
		earthquakeSound:Play()
	end

	local v5 =
		CollectionService:GetTagged(
			"PartCeiling"
		)

	local v6 = {}

	for _, v7 in v5 do

		local v8 =
			v7.Size.Magnitude * 0.7

		local v9 =
			math.clamp(
				v8,
				0,
				150
			)

		local particles =
			Assets.Earthquake:FindFirstChild(
				"Particles"
			)

		if not particles then
			continue
		end

		for _, v10 in
			particles:GetChildren() do

			local v11 =
				v10:Clone()

			v11.Parent =
				v7

			v11:Emit(
				v9 / 10
			)

			v11.Enabled = true

			table.insert(
				v6,
				v11
			)
		end
	end

	task.wait(4)

	for _, v12 in v6 do

		if v12.Parent then
			v12.Enabled = false
		end
	end
end

-- \\ Setup // --

for name, value in
	next,
	CONST.ATTR.PLAYER do

	LocalPlayer:SetAttribute(
		name,
		value
	)
end

LastRespawn =
	tick()
	-
	(
		tonumber(
			LocalPlayer:GetAttribute(
				"SpawnProtection"
			)
		)
		or 5
	)
LocalPlayer.CharacterAdded:Connect(
	OnCharacterAdded
)

-- \\ Main // --

Module.Create =
	function(config)

		local newConfig =
			NormalizeConfig(config)

		newConfig.Movement.Speed =
			CONST.BASE_ENTITY_SPEED
			/ 100
			*
			newConfig.Movement.Speed

		-- \\ Entity asset // --

		local asset =
			newConfig.Entity.Asset

		if asset == nil
			or (
				typeof(asset) == "string"
				and asset == ""
			)
		then

			error(
				"Entity.Asset is required for '"
				.. tostring(newConfig.Entity.Name)
				.. "'."
			)
		end

		local success = false
		local entityModel

		if typeof(asset) == "Instance" then

			if asset:IsA("Model") then

				success = true
				entityModel = asset

			else

				error(
					"Entity.Asset for '"
					.. tostring(newConfig.Entity.Name)
					.. "' must be a Model."
				)
			end

		elseif typeof(asset) == "string" then

			success, entityModel =
				pcall(function()

					local instance =
						LoadCustomInstance(
							asset
						)

					if typeof(instance)
						~= "Instance"
					then

						error(
							"Failed to fetch entity model."
						)
					end

					if not instance:IsA("Model") then

						error(
							"Entity asset must be a Model."
						)
					end

					return instance
				end)

		else

			error(
				"Invalid Entity.Asset for '"
				.. tostring(newConfig.Entity.Name)
				.. "'."
			)
		end

		if not (
			success
			and entityModel
			and entityModel:IsA("Model")
		) then

			error(
				"Failed to create entity '"
				.. tostring(newConfig.Entity.Name)
				.. "': the supplied Entity.Asset could not be loaded as a Model."
			)
		end

		local rootPart =
			entityModel.PrimaryPart
			or entityModel:FindFirstChildWhichIsA(
				"BasePart",
				true
			)

		if not rootPart then

			error(
				"Failed to create entity '"
				.. tostring(newConfig.Entity.Name)
				.. "': no BasePart was found in the supplied Model."
			)
		end

		rootPart.Anchored = true

		entityModel.PrimaryPart =
			rootPart

		local name =
			newConfig.Entity.Name

		if typeof(name) == "string"
			and name ~= ""
		then

			entityModel.Name =
				name
		end

		for attr, val in
			next,
			CONST.ATTR.ENTITY do

			entityModel:SetAttribute(
				attr,
				val
			)
		end

		local c =
			Instance.new(
				"Configuration"
			)

		c.Name =
			"RoomsEntered"

		c.Parent =
			entityModel

		return {
			Model = entityModel,

			Config = newConfig,

			Debug =
				CloneTable(
					CONST.DEFAULT.DEBUG
				),

			SetCallback =
				function(
					self,
					key,
					callback
				)

					assert(
						typeof(key) == "string",
						"Callback key is invalid."
					)

					if key == "OnReachNode" then
						key =
							"OnReachedNode"
					end

					local valid =
						self.Debug[key] ~= nil
						or key ==
							"CrucifixionOverwrite"

					assert(
						valid,
						"Callback key is invalid: "
						.. tostring(key)
					)

					assert(
						typeof(callback) == "function",
						"Callback must be a function."
					)

					self.Debug[key] =
						callback
				end,

			RunCallback =
				function(
					self,
					key,
					...
				)

					if key == "OnReachNode" then
						key =
							"OnReachedNode"
					end

					local callback =
						self.Debug[key]

					if typeof(callback)
						== "function"
					then

						local success,
							result =
							pcall(
								callback,
								...
							)

						if not success then
							warn(result)
						end
					end
				end,

			IsAlive =
				function(self)
					return
						self.Model
						and self.Model.Parent
				end,

			Pause =
				function(self)

					if self:IsAlive() then

						self.Model:SetAttribute(
							"Paused",
							true
						)
					end
				end,

			Resume =
				function(self)

					if self:IsAlive() then

						self.Model:SetAttribute(
							"Paused",
							false
						)
					end
				end,

			Run =
				function(
					self,
					copyEntity
				)

					Module:Run(
						self,
						copyEntity
					)
				end,

			Despawn =
				function(self)

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

Module.Run =
	function(self, entity, copyEntity)

		if copyEntity == true then

			self:Run(
				CloneTable(entity),
				false
			)

			return
		end

		if not entity
			or not entity.Model
		then
			return
		end

		if entity.Model:GetAttribute(
			"Running"
		) then
			return
		end

		local model =
			entity.Model

		local config =
			entity.Config

		local debug =
			entity.Debug

		model:SetAttribute(
			"Running",
			true
		)

		self.ActiveEntities[
			#self.ActiveEntities + 1
		] = entity

		-- \\ Spawn point // --

		local spawnPoint

		do

			local rooms =
				GetSortedRooms()

			if #rooms <= 0 then

				model:SetAttribute(
					"Running",
					false
				)

				local i =
					table.find(
						self.ActiveEntities,
						entity
					)

				if i then
					table.remove(
						self.ActiveEntities,
						i
					)
				end

				warn(
					"Failed to run entity '"
					.. tostring(config.Entity.Name)
					.. "': no rooms are currently available."
				)

				return
			end

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

			model:SetAttribute(
				"Running",
				false
			)

			warn(
				"Failed to find spawn point for entity: "
				.. tostring(
					config.Entity.Name
				)
			)

			local i =
				table.find(
					self.ActiveEntities,
					entity
				)

			if i then
				table.remove(
					self.ActiveEntities,
					i
				)
			end

			return
		end

		model:PivotTo(
			spawnPoint.CFrame
			+
			Vector3.new(
				0,
				config.Entity.HeightOffset,
				0
			)
		)

		model.Parent =
			workspace

		task.spawn(
			entity.RunCallback,
			entity,
			"OnSpawned"
		)

		-- \\ Spawn effects // --

		local currentRoom =
			GetCurrentRoom(false)

		if currentRoom then

			if config.Lights.Flicker.Enabled then

				pcall(
					function()

						Modules.Module_Events.flicker(
							currentRoom,
							config.Lights.Flicker.Duration
						)
					end
				)
			end

			if config.Earthquake.Enabled then

				task.spawn(
					Earthquake
				)
			end
		end

		task.wait(
			config.Movement.Delay
		)

		if not entity:IsAlive() then
			return
		end

		task.spawn(
			entity.RunCallback,
			entity,
			"OnStartMoving"
		)

		-- \\ Detection / damage loop // --

		task.spawn(function()

			while entity:IsAlive()
				and task.wait()
			do

				if model:GetAttribute(
					"Paused"
				) then
					continue
				end

				if not RootPart
					or not RootPart.Parent
				then
					break
				end

				local origin =
					model:GetPivot().Position

				local charOrigin =
					RootPart.Position

				local inSight = false

				local distance =
					(
						charOrigin
						- origin
					).Magnitude

				if distance
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

					Camera =
						workspace.CurrentCamera

					if Camera then

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
				end

				-- \\ Room detection // --

				do

					local room =
						GetRoomAtPoint(
							origin
						)

					if room then

						local index =
							tonumber(
								room.Name
							)

						if index
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
									GetCurrentRoom(
										true
									)

								if room ~= latestRoom then

									if config.Lights.Shatter then

										pcall(
											function()

												Modules.Module_Events.shatter(
													room
												)
											end
										)

									elseif config.Lights.Repair then

										pcall(
											function()

												FixRoomLights(
													room
												)
											end
										)
									end
								end
							end
						end
					end
				end

				-- \\ Crucifix // --

				local usedCrucifix =
					false

				do

					local crucifixion =
						config.Crucifixion

					if crucifixion.Enabled
						and crucifixion.Range > 0
						and distance
							<= crucifixion.Range
						and inSight
					then

						local hasTool, tool =
							HasEquipped(
								"Crucifix"
							)

						if hasTool
							and tool
							and not model:GetAttribute(
								"BeingBanished"
							)
						then

							if typeof(
								debug.CrucifixionOverwrite
							) == "function"
							then

								entity:RunCallback(
									"CrucifixionOverwrite"
								)

							else

								tool:Destroy()

								model:SetAttribute(
									"Paused",
									true
								)

								CrucifixEntity(
									entity
								)
							end

							usedCrucifix =
								true
						end
					end
				end

				-- \\ Damage // --

				if not model:GetAttribute(
					"Paused"
				)
					and not usedCrucifix
				then

					local damage =
						config.Damage

					if damage.Enabled
						and damage.Range > 0
						and Humanoid.Health > 0
						and (
							not Character:GetAttribute(
								"Hiding"
							)
							or damage.IgnoreHiding
						)
						and model:GetAttribute(
							"Damage"
						)
						and not model:GetAttribute(
							"BeingBanished"
						)
						and distance
							<= damage.Range
						and inSight
					then

						model:SetAttribute(
							"Damage",
							false
						)

						DamagePlayer(
							entity
						)
					end
				end

				-- \\ Camera shake // --

				do

					local camShake =
						config.CameraShake

					if camShake.Enabled
						and camShake.Range > 0
					then

						local mag =
							distance

						if mag
							<= camShake.Range
						then

							local cloned = {}

							for i = 1, 4 do

								cloned[i] =
									camShake.Values[i]
							end

							local multiplier =
								(
									camShake.Range
									- mag
								)
								/
								camShake.Range

							cloned[1] =
								camShake.Values[1]
								*
								multiplier

							cloned[2] =
								camShake.Values[2]
								*
								multiplier

							Modules.Main_Game.camShaker:ShakeOnce(
								table.unpack(
									cloned
								)
							)
						end
					end
				end
			end
		end)

		-- \\ Movement // --

		task.spawn(function()

			local reboundType =
				(
					config.Rebounding.Type
					or "Ambush"
				):upper()

			if reboundType == "AMBUSH" then

				local pathfindNodes =
					GetPathfindNodesAmbush(
						config
					)

				for _, v in next,
					pathfindNodes do

					if not entity:IsAlive() then
						break
					end

					local cframe =
						v.CFrame
						+
						Vector3.new(
							0,
							3
								+
								config.Entity.HeightOffset,
							0
						)

					if not EntityMoveTo(
						model,
						cframe,
						config.Movement.Speed
					) then
						break
					end

					task.spawn(
						entity.RunCallback,
						entity,
						"OnReachedNode",
						v
					)
				end

				if entity:IsAlive()
					and config.Rebounding.Enabled
				then

					local reboundsCount =
						math.random(
							config.Rebounding.Min,
							config.Rebounding.Max
						)

					for i = 1,
						reboundsCount do

						if not entity:IsAlive() then
							break
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
							true
						)

						for i = #pathfindNodes,
							1,
							-1 do

							if not entity:IsAlive() then
								break
							end

							local v =
								pathfindNodes[i]

							local cframe =
								v.CFrame
								+
								Vector3.new(
									0,
									3
										+
										config.Entity.HeightOffset,
									0
								)

							if not EntityMoveTo(
								model,
								cframe,
								config.Movement.Speed
							) then
								break
							end

							task.spawn(
								entity.RunCallback,
								entity,
								"OnReachedNode",
								v
							)
						end

						if not entity:IsAlive() then
							break
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

						if not entity:IsAlive() then
							break
						end

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

							if not entity:IsAlive() then
								break
							end

							local cframe =
								v.CFrame
								+
								Vector3.new(
									0,
									3
										+
										config.Entity.HeightOffset,
									0
								)

							if not EntityMoveTo(
								model,
								cframe,
								config.Movement.Speed
							) then
								break
							end

							task.spawn(
								entity.RunCallback,
								entity,
								"OnReachedNode",
								v
							)
						end

						if not entity:IsAlive() then
							break
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
					GetPathfindNodesBlitz(
						config
					)

				for _, n in next,
					nodesToCurrent do

					if not entity:IsAlive() then
						break
					end

					local cframe =
						n.CFrame
						+
						Vector3.new(
							0,
							3
								+
								config.Entity.HeightOffset,
							0
						)

					if not EntityMoveTo(
						model,
						cframe,
						config.Movement.Speed
					) then
						break
					end

					task.spawn(
						entity.RunCallback,
						entity,
						"OnReachedNode",
						n
					)
				end

				if entity:IsAlive()
					and config.Rebounding.Enabled
				then

					local currentRoom =
						GetCurrentRoom(false)

					if currentRoom then

						local roomNodes =
							GetNodesFromRoom(
								currentRoom,
								config.Movement.Reversed
							)

						if #roomNodes > 1 then

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

							if randomNode then

								local nodeIndex =
									tonumber(
										randomNode.Name
									)

								if not nodeIndex then
									nodeIndex = 1
								end

								nodeIndex =
									math.clamp(
										nodeIndex,
										1,
										#roomNodes
									)

								local reboundCount =
									math.random(
										config.Rebounding.Min,
										config.Rebounding.Max
									)

								for _ = 1,
									reboundCount do

									if not entity:IsAlive() then
										break
									end

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

									for i = #roomNodes,
										nodeIndex,
										-1 do

										if not entity:IsAlive() then
											break
										end

										local node =
											roomNodes[
												math.clamp(
													i,
													1,
													#roomNodes
												)
											]

										local cframe =
											node.CFrame
											+
											Vector3.new(
												0,
												3
													+
													config.Entity.HeightOffset,
												0
											)

										if not EntityMoveTo(
											model,
											cframe,
											config.Movement.Speed
										) then
											break
										end

										task.spawn(
											entity.RunCallback,
											entity,
											"OnReachedNode",
											node
										)
									end

									if not entity:IsAlive() then
										break
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

										if not entity:IsAlive() then
											break
										end

										local node =
											roomNodes[
												math.clamp(
													i,
													1,
													#roomNodes
												)
											]

										local cframe =
											node.CFrame
											+
											Vector3.new(
												0,
												3
													+
													config.Entity.HeightOffset,
												0
											)

										if not EntityMoveTo(
											model,
											cframe,
											config.Movement.Speed
										) then
											break
										end

										task.spawn(
											entity.RunCallback,
											entity,
											"OnReachedNode",
											node
										)
									end
								end
							end
						end
					end
				end

				if entity:IsAlive() then

					local _, updatedToEnd =
						GetPathfindNodesBlitz(
							config
						)

					for _, n in next,
						updatedToEnd do

						if not entity:IsAlive() then
							break
						end

						local cframe =
							n.CFrame
							+
							Vector3.new(
								0,
								3
									+
									config.Entity.HeightOffset,
								0
							)

						if not EntityMoveTo(
							model,
							cframe,
							config.Movement.Speed
						) then
							break
						end

						task.spawn(
							entity.RunCallback,
							entity,
							"OnReachedNode",
							n
						)
					end
				end
			end

			-- \\ Despawn // --

			if model.Parent
				and not model:GetAttribute(
					"Despawning"
				)
			then

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
					model:GetPivot()
					-
					Vector3.new(
						0,
						300,
						0
					),
					config.Movement.Speed
				)

				entity:Despawn()
			end
		end)
	end

-- \\ Internal setup // --

if not getgenv()._internal_vynixu_entity_spawner then

	getgenv()._internal_vynixu_entity_spawner =
		true

	local function GetAmbient(room)
		return
			room:GetAttribute(
				"AmbientOriginal"
			)
			or room:GetAttribute(
				"Ambient"
			)
			or Color3.fromRGB(
				67,
				51,
				56
			)
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

				if instance.Name ==
					"PathfindNodes"
				then

					local latestRoom =
						GetCurrentRoom(
							true
						)

					if latestRoom then

						local clone =
							instance:Clone()

						clone.Parent =
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

-- \\ Module functions // --

Module.Clear =
	function(self)

		for i = #self.ActiveEntities,
			1,
			-1 do

			local entity =
				self.ActiveEntities[i]

			if entity then
				entity:Despawn()
			end
		end

		table.clear(
			self.ActiveEntities
		)
	end

Module.Unload =
	function(self)

		self:Clear()

		for i, connection in
			next,
			self.Connections do

			if connection then
				connection:Disconnect()
			end

			self.Connections[i] =
				nil
		end

		for i in next, self do
			self[i] = nil
		end
	end

getgenv().VynixuEntitySpawnerV2 =
	Module

return Module