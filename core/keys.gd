class_name Keys
extends RefCounted
## String keys shared between content (.tres) and the rules engine.

const TANK := "tank"
const HEALER := "healer"
const DPS := "dps"
const CC := "cc"

const MURDER_HOBO := "murder_hobo"
const MAIN_CHARACTER := "main_character"
const RULE_LAWYER := "rule_lawyer"
const QUIET := "quiet"

const STATUS_NONE := ""
const STATUS_PHONE := "phone"
const STATUS_DICE_TOWER := "dice_tower"
const STATUS_TOXIC := "toxic"
const STATUSES: Array[String] = [STATUS_PHONE, STATUS_DICE_TOWER, STATUS_TOXIC]

const FLAG_POISON := "poison"
const FLAG_NO_STUN := "nostun"
