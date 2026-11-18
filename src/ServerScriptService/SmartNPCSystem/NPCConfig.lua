return {
	-- Population and spawn/respawn
	NPCCount = 15,
	RespawnDelay = 5,
	MinimumSpawnSpacing = 12,
	SpawnAttempts = 50,
	
	-- Awareness and movement
	DetectionRange = 80,
	WanderRadius = 45,
	WanderMinDistance = 8,
	IdleMin = 2,
	IdleMax = 6,
	InvestigateSeconds = 12,
	SearchSeconds = 15,
	SearchRadius = 18,
	ThinkInterval = 0.3,
	PathRefreshInterval = 1.25,
	
	-- Combat
	AttackDamage = 15,
	AttackRange = 5,
	AttackCooldown = 1.2,
	FearHealthPercent = 0.3,
	
	-- Optional team/faction filtering and tools
	UseFactions = false,
	GearFolderName = "NPCGear",
	
	-- Optional emotion billboard above NPC heads
	ShowEmotionLabel = true,
}
