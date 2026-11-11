class_name AssetFrames
extends Object

const BUBBLE := 654
const BUBBLE_N := 3
const BUBBLE_LIGHT := 657
const BUBBLE_LIGHT_N := 3
const CLEAN := 660
const CLEAN_N := 2
const SPLASH := 662
const SPLASH_N := 3
const SMOKE := 665
const SMOKE_N := 13
const AURA := 678
const AURA_N := 1
const SPARK := 679
const SPARK_N := 1
const GLITCH := 680
const GLITCH_N := 3
const TILE_GLITCH := 683
const TILE_GLITCH_N := 4
const HAND := 687
const HAND_N := 4
const FIRE := 691
const FIRE_N := 15
const GLITCH_HOUSE := 706
const GLITCH_HOUSE_N := 1
const GLITCH_TREE := 707
const GLITCH_TREE_N := 1
const WASTE_TREE := 708
const WASTE_TREE_N := 1
const ANOMALY := 709
const ANOMALY_N := 1
const ANOMALY_RAY := 710
const ANOMALY_RAY_N := 1
const EPILOGUE := 711
const EPILOGUE_N := 4
const ROTTEN_APPLE := 716
const ROTTEN_APPLE_N := 1
const SUDS := 717
const SUDS_N := 1
const GLITCH_TREE_C := 718
const GLITCH_TREE_C_N := 1
const GLITCH_TREE_D := 719
const GLITCH_TREE_D_N := 1
const WASTE_TREE_B := 720
const WASTE_TREE_B_N := 1
const EPI_APPLE := 721
const EPI_APPLE_N := 1
const MOUNT_BIG := 722
const MOUNT_BIG_N := 1
const MOUNT_SMALL := 723
const MOUNT_SMALL_N := 1
const MOUNT_GLITCH := 724
const MOUNT_GLITCH_N := 1
const GRASS_PATCH := 725
const GRASS_PATCH_N := 1
const FUMES := 726
const FUMES_N := 8
const FIRE_BLOB := 734
const FIRE_BLOB_N := 8

static func frame(start: int, count: int, tick: int) -> int:
	if count <= 0:
		return -1
	return start + posmod(tick, count)

