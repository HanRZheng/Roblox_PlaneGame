--!strict

-- V23 ships original WAV source files in the downloadable project. Roblox audio
-- must be uploaded by the experience owner, so these IDs intentionally remain
-- empty until the files are uploaded under that owner's account.
local sharedSounds = {
	IDLE = "",
	POWER = "",
	TAKEOFF = "",
	REVERSE = "",
	SHUTDOWN = "",
}

local profiles = {
	GEARED_NARROW = { FanBladeCount = 20, SoundIds = sharedSounds },
	NARROW_HIGH_BYPASS = { FanBladeCount = 24, SoundIds = sharedSounds },
	WIDE_TRENT = { FanBladeCount = 22, SoundIds = sharedSounds },
	WIDE_CHEVRON = { FanBladeCount = 18, SoundIds = sharedSounds },
	WIDE_CLASSIC = { FanBladeCount = 26, SoundIds = sharedSounds },
	WIDE_GE = { FanBladeCount = 16, SoundIds = sharedSounds },
	GEARED_REGIONAL = { FanBladeCount = 20, SoundIds = sharedSounds },
	REGIONAL_REAR = { FanBladeCount = 28, SoundIds = sharedSounds },
}

return {
	Profiles = profiles,
	GetProfile = function(profileName: string)
		return profiles[profileName] or profiles.NARROW_HIGH_BYPASS
	end,
}
