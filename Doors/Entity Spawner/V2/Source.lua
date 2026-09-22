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

local function PlayJumpscare(config)
	if typeof(config) ~= "table"
		or config[1] ~= true
	then
		return
	end

	local s =
		config[2]

	if typeof(s) ~= "table" then
		return
	end

	local oldGui =
		CoreGui:FindFirstChild(
			"JumpscareGui"
		)

	if oldGui then
		oldGui:Destroy()
	end

	local gui =
		Instance.new("ScreenGui")

	gui.Name =
		"JumpscareGui"

	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999

	gui.Parent =
		CoreGui

	local bg =
		Instance.new("Frame")

	bg.Size =
		UDim2.fromScale(
			1,
			1
		)

	bg.BackgroundColor3 =
		Color3.new(
			0,
			0,
			0
		)

	bg.BorderSizePixel = 0
	bg.Parent = gui

	local face =
		Instance.new("ImageLabel")

	face.AnchorPoint =
		Vector2.new(
			0.5,
			0.5
		)

	face.Position =
		UDim2.fromScale(
			0.5,
			0.5
		)

	face.Size =
		UDim2.fromOffset(
			150,
			150
		)

	face.BackgroundTransparency = 1
	face.ImageTransparency = 0

	pcall(function()
		face.ResampleMode =
			Enum.ResamplerMode.Pixelated
	end)

	if typeof(s.Image1) == "string" then
		pcall(function()

			local image =
				LoadCustomAsset(
					s.Image1
				)

			if image then
				face.Image =
					image
			end
		end)
	end

	face.Parent =
		gui

	local function LoadSound(data)
		if typeof(data) ~= "table"
			or data[1] == nil
		then
			return nil
		end

		local sound =
			Instance.new("Sound")

		local soundId =
			tostring(data[1])

		if soundId:match(
			"^rbxassetid://"
		) then

			sound.SoundId =
				soundId

		else

			sound.SoundId =
				"rbxassetid://" .. soundId
		end

		if typeof(data[2]) == "table" then

			for property, value in pairs(
				data[2]
			) do

				pcall(function()

					sound[property] =
						value
				end)
			end
		end

		sound.Parent =
			SoundService

		return sound
	end

	local sound1 =
		LoadSound(
			s.Sound1
		)

	local sound2 =
		LoadSound(
			s.Sound2
		)

	-- \\ Tease // --

	if typeof(s.Tease) == "table"
		and s.Tease[1] == true
	then

		local min =
			math.max(
				1,
				math.floor(
					tonumber(
						s.Tease.Min
					)
					or 1
				)
			)

		local max =
			math.max(
				min,
				math.floor(
					tonumber(
						s.Tease.Max
					)
					or 5
				)
			)

		local count =
			math.random(
				min,
				max
			)

		for i = 1, count do

			if sound1 then
				sound1:Play()
			end

			task.wait(
				math.random(
					100,
					200
				) / 100
			)

			local size =
				150 + i * 75

			face.Size =
				UDim2.fromOffset(
					size,
					size
				)
		end
	end

	-- \\ Flashing // --

	local flashThread

	if typeof(s.Flashing) == "table"
		and s.Flashing[1] == true
	then

		local flashColor =
			typeof(s.Flashing[2]) == "Color3"
			and s.Flashing[2]
			or Color3.new(
				1,
				1,
				1
			)

		flashThread =
			task.spawn(function()

				while gui.Parent do

					bg.BackgroundColor3 =
						flashColor

					task.wait(
						math.random(
							25,
							100
						) / 1000
					)

					if not gui.Parent then
						break
					end

					bg.BackgroundColor3 =
						Color3.new(
							0,
							0,
							0
						)

					task.wait(
						math.random(
							25,
							100
						) / 1000
					)
				end
			end)
	end

	-- \\ Shake // --

	local shakeConnection

	if s.Shake == true then

		shakeConnection =
			RunService.RenderStepped:Connect(
				function()

					if not face.Parent then
						return
					end

					face.Position =
						UDim2.new(
							0.5,
							math.random(
								-35,
								35
							),
							0.5,
							math.random(
								-10,
								10
							)
						)

					face.Rotation =
						math.random(
							-5,
							5
						)
				end
			)
	end

	-- \\ Image 2 + Sound 2 // --

	if typeof(s.Image2) == "string" then
		pcall(function()

			local image =
				LoadCustomAsset(
					s.Image2
				)

			if image then
				face.Image =
					image
			end
		end)
	end

	if sound2 then
		sound2:Play()
	end

	-- \\ Zoom // --

	local camera =
		workspace.CurrentCamera

	local viewportHeight =
		camera
		and camera.ViewportSize.Y
		or 1080

	local zoomSize =
		viewportHeight * 3

	local zoomTween =
		TweenService:Create(
			face,

			TweenInfo.new(
				1.5,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.Out
			),

			{
				Size =
					UDim2.fromOffset(
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
		task.cancel(
			flashThread
		)
	end

	if sound1 then
		sound1:Stop()
		sound1:Destroy()
	end

	if sound2 then
		sound2:Stop()
		sound2:Destroy()
	end

	if gui then
		gui:Destroy()
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
		