#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>

#define MAX_ENTS 512

// TODO: when switching the same 2 weapons over and over, it breaks them

new g_srcWeapon[32], g_dstWeapon[32]
new g_srcAmmo[32], g_dstAmmo[32]
new g_srcItem[32], g_dstItem[32]

new g_entityEnt[MAX_ENTS]
new g_entityOrigin[MAX_ENTS][3]
new g_entityType[MAX_ENTS]
new g_entityCount = 0

new g_savedClassname[MAX_ENTS][32]
new g_savedOrigin[MAX_ENTS][3]
new g_savedCount = 0
new bool:g_hasSaved = false

new g_currentBatch = 0
new bool:g_deleteOnly = false

new const g_weapons[][] = {
	"crowbar", "9mmAR", "357", "mp5", "chaingun", 
	"crossbow", "shotgun", "rpg", "gauss", "egon", 
	"hornetgun", "handgrenade", "snark"
}

new const g_weaponAmmo[][] = {
	"",             // crowbar
	"ammo_9mmclip", // 9mmAR
	"ammo_357",     // 357
	"ammo_9mmclip", // mp5
	"ammo_9mmclip", // chaingun
	"ammo_crossbow", // crossbow
	"ammo_buckshot", // shotgun
	"ammo_rpgclip",  // rpg
	"ammo_gaussclip", // gauss
	"ammo_gaussclip", // egon
	"ammo_hornets",  // hornetgun
	"ammo_argrenades", // handgrenade
	""              // snark
}

new const g_ammos[][] = {
	"9mmclip", "357", "crossbow", "buckshot", "rpgclip", 
	"gaussclip", "hornets", "argrenades"
}

new const g_items[][] = {
	"longjump", "healthkit", "battery", "suit", "armor"
}

public plugin_init()
{
	register_plugin("Hot Switch", "1.1", "Daniel")
	register_clcmd("hs", "cmdHS", ADMIN_BAN, "- Hot Switch: hs <weapon|ammo|item|list|save|reset> [target] [replacement]")
	register_srvcmd("hs", "cmdHS", ADMIN_BAN, "- Hot Switch: hs <weapon|ammo|item|list|save|reset> [target] [replacement]")
	register_clcmd("hs weapon", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs weapon", "cmdHS", ADMIN_BAN)
	register_clcmd("hs ammo", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs ammo", "cmdHS", ADMIN_BAN)
	register_clcmd("hs item", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs item", "cmdHS", ADMIN_BAN)
	register_clcmd("hs list", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs list", "cmdHS", ADMIN_BAN)
	register_clcmd("hs save", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs save", "cmdHS", ADMIN_BAN)
	register_clcmd("hs reset", "cmdHS", ADMIN_BAN)
	register_srvcmd("hs reset", "cmdHS", ADMIN_BAN)
}

public cmdHS(id, level, cid)
{
	new argCount = read_argc()
	
	if (argCount < 2)
	{
		client_print(id, print_console, "Usage: hs <weapon|ammo|item|list|save|reset> [target] [replacement]")
		client_print(id, print_console, "Examples:")
		client_print(id, print_console, "  hs weapon crossbow gauss")
		client_print(id, print_console, "  hs weapon @all @none")
		client_print(id, print_console, "  hs ammo 9mmclip gaussclip")
		client_print(id, print_console, "  hs ammo @all @none")
		client_print(id, print_console, "  hs item longjump @none")
		client_print(id, print_console, "  hs list")
		client_print(id, print_console, "  hs weapon list")
		client_print(id, print_console, "  hs save")
		client_print(id, print_console, "  hs reset")
		return PLUGIN_HANDLED
	}

	new subCmd[32]
	read_argv(1, subCmd, charsmax(subCmd))

	if (equal(subCmd, "list")) return cmdListEntities(id, level, cid)
	if (equal(subCmd, "save")) return cmdSaveMap(id, level, cid)
	if (equal(subCmd, "reset")) return cmdResetMap(id, level, cid)

	new target[32]
	read_argv(2, target, charsmax(target))

	if (equal(target, "list"))
	{
		if (equal(subCmd, "weapon")) return cmdListEntitiesSpecific(id, level, cid, "weapon_")
		else if (equal(subCmd, "ammo")) return cmdListEntitiesSpecific(id, level, cid, "ammo_")
		else if (equal(subCmd, "item")) return cmdListEntitiesSpecific(id, level, cid, "item_")
		else
		{
			client_print(id, print_console, "Invalid subcommand: %s", subCmd)
			return PLUGIN_HANDLED
		}
	}

	if (argCount < 4)
	{
		client_print(id, print_console, "Usage: hs %s <target> <replacement>", subCmd)
		return PLUGIN_HANDLED
	}

	new replacement[32]
	read_argv(3, replacement, charsmax(replacement))

	new len = strlen(replacement)
	while (len > 0 && replacement[len-1] == ' ')
		len--
	replacement[len] = 0

	if (equal(subCmd, "weapon")) return handleWeaponSwitch(id, target, replacement)
	else if (equal(subCmd, "ammo")) return handleAmmoSwitch(id, target, replacement)
	else if (equal(subCmd, "item")) return handleItemSwitch(id, target, replacement)
	else
	{
		client_print(id, print_console, "Invalid subcommand: %s", subCmd)
		return PLUGIN_HANDLED
	}
}

public handleWeaponSwitch(id, srcWeapon[], dstWeapon[])
{
	g_deleteOnly = false

	new srcIdx = getWeaponIndex(srcWeapon)
	if (srcIdx == -1)
	{
		client_print(id, print_console, "Invalid source weapon: %s", srcWeapon)
		client_print(id, print_console, "Valid weapons: crowbar, 9mmAR, 357, mp5, chaingun, crossbow, shotgun, rpg, gauss, egon, hornetgun, handgrenade, snark")
		return PLUGIN_HANDLED
	}

	if (equal(dstWeapon, "@none"))
	{
		if (equal(srcWeapon, "crowbar"))
		{
			client_print(id, print_console, "Cannot delete crowbar spawns")
			return PLUGIN_HANDLED
		}
		g_deleteOnly = true
	}
	else
	{
		new dstIdx = getWeaponIndex(dstWeapon)
		if (dstIdx == -1)
		{
			client_print(id, print_console, "Invalid target weapon: %s", dstWeapon)
			client_print(id, print_console, "Valid weapons: crowbar, 9mmAR, 357, mp5, chaingun, crossbow, shotgun, rpg, gauss, egon, hornetgun, handgrenade, snark")
			return PLUGIN_HANDLED
		}
	}

	copy(g_srcWeapon, charsmax(g_srcWeapon), srcWeapon)
	copy(g_dstWeapon, charsmax(g_dstWeapon), dstWeapon)

	client_print(0, print_chat, "[Hot Switch] Weapon switch in progress...")

	stripPlayerWeapons()
	set_task(0.5, "delayedWeaponSwitch")

	return PLUGIN_HANDLED
}

public handleAmmoSwitch(id, srcAmmo[], dstAmmo[])
{
	g_deleteOnly = false

	if (!isValidAmmo(srcAmmo) && !equal(srcAmmo, "@all"))
	{
		client_print(id, print_console, "Invalid source ammo: %s", srcAmmo)
		client_print(id, print_console, "Valid ammo: 9mmclip, 357, crossbow, buckshot, rpgclip, gaussclip, hornets, argrenades")
		return PLUGIN_HANDLED
	}

	if (equal(dstAmmo, "@none")) g_deleteOnly = true
	else if (!isValidAmmo(dstAmmo))
	{
		client_print(id, print_console, "Invalid target ammo: %s", dstAmmo)
		client_print(id, print_console, "Valid ammo: 9mmclip, 357, crossbow, buckshot, rpgclip, gaussclip, hornets, argrenades")
		return PLUGIN_HANDLED
	}

	copy(g_srcAmmo, charsmax(g_srcAmmo), srcAmmo)
	copy(g_dstAmmo, charsmax(g_dstAmmo), dstAmmo)

	client_print(0, print_chat, "[Hot Switch] Ammo switch in progress...")
	set_task(0.5, "delayedAmmoSwitch")

	return PLUGIN_HANDLED
}

public handleItemSwitch(id, srcItem[], dstItem[])
{
	g_deleteOnly = false

	if (!isValidItem(srcItem) && !equal(srcItem, "@all"))
	{
		client_print(id, print_console, "Invalid source item: %s", srcItem)
		client_print(id, print_console, "Valid items: longjump, healthkit, battery, suit, armor")
		return PLUGIN_HANDLED
	}

	if (equal(dstItem, "@none")) g_deleteOnly = true
	else if (!isValidItem(dstItem))
	{
		client_print(id, print_console, "Invalid target item: %s", dstItem)
		client_print(id, print_console, "Valid items: longjump, healthkit, battery, suit, armor")
		return PLUGIN_HANDLED
	}

	copy(g_srcItem, charsmax(g_srcItem), srcItem)
	copy(g_dstItem, charsmax(g_dstItem), dstItem)

	client_print(0, print_chat, "[Hot Switch] Item switch in progress...")
	set_task(0.5, "delayedItemSwitch")

	return PLUGIN_HANDLED
}

public delayedWeaponSwitch()
{
	new src[32], dst[32]
	copy(src, charsmax(src), g_srcWeapon)
	copy(dst, charsmax(dst), g_dstWeapon)

	new dstIdx = getWeaponIndex(dst)
	new dstAmmo[32]
	if (dstIdx >= 0 && strlen(g_weaponAmmo[dstIdx]) > 0)
	{
		copy(dstAmmo, charsmax(dstAmmo), g_weaponAmmo[dstIdx])
		copy(g_dstAmmo, charsmax(g_dstAmmo), dstAmmo)
	}
	else 
	{
		dstAmmo[0] = 0
		g_dstAmmo[0] = 0
	}

	stripPlayerWeapons()
	g_entityCount = 0

	if (equal(src, "@all"))
	{
		for (new w = 0; w < sizeof g_weapons; w++)
		{
			collectEntities("weapon", g_weapons[w], 0)
			if (strlen(g_weaponAmmo[w]) > 0)
			{
				new ammoName[32]
				getAmmoShortName(g_weaponAmmo[w], ammoName)
				collectEntities("ammo", ammoName, 1)
			}
		}
	}
	else
	{
		new srcIdx = getWeaponIndex(src)
		if (srcIdx == -1)
		{
			client_print(0, print_console, "Invalid source weapon: %s", src)
			return
		}
		collectEntities("weapon", src, 0)
		if (strlen(g_weaponAmmo[srcIdx]) > 0)
		{
			new ammoName[32]
			getAmmoShortName(g_weaponAmmo[srcIdx], ammoName)
			collectEntities("ammo", ammoName, 1)
		}
	}

	removeCollected()

	new total = g_entityCount
	
	if (total > 0)
	{
		if (g_deleteOnly)
		{
			client_print(0, print_chat, "[Hot Switch] Deleted %d weapon/ammo spawn(s)", total)
			server_print("[Hot Switch] Deleted %d weapon/ammo spawn(s)", total)
		}
		else
		{
			client_print(0, print_chat, "[Hot Switch] Replaced %d entity spawn(s) with %s", total, dst)
			server_print("[Hot Switch] Replaced %d entity spawn(s) with %s", total, dst)
		}
	}
	else
	{
		client_print(0, print_console, "No weapon spawns found on this map")
	}

	if (g_deleteOnly)
	{
		stripPlayerWeapons()
		client_print(0, print_chat, "[Hot Switch] Weapons deleted!")
	}
	else
	{
		g_currentBatch = 0
		set_task(0.3, "createNextBatch")
	}
}

public delayedAmmoSwitch()
{
	new src[32], dst[32]
	copy(src, charsmax(src), g_srcAmmo)
	copy(dst, charsmax(dst), g_dstAmmo)

	g_entityCount = 0

	if (equal(src, "@all"))
	{
		for (new i = 0; i < sizeof g_ammos; i++)
		{
			collectEntities("ammo", g_ammos[i], 1)
		}
	}
	else
	{
		collectEntities("ammo", src, 1)
	}

	removeCollected()

	new total = g_entityCount
	
	if (total > 0)
	{
		if (g_deleteOnly)
		{
			client_print(0, print_chat, "[Hot Switch] Deleted %d ammo spawn(s)", total)
			server_print("[Hot Switch] Deleted %d ammo spawn(s)", total)
		}
		else
		{
			client_print(0, print_chat, "[Hot Switch] Replaced %d ammo spawn(s) with %s", total, dst)
			server_print("[Hot Switch] Replaced %d ammo spawn(s) with %s", total, dst)
		}
	}
	else
	{
		client_print(0, print_console, "No ammo spawns found on this map")
	}

	if (!g_deleteOnly)
	{
		g_currentBatch = 0
		set_task(0.3, "createNextBatch")
	}
}

public delayedItemSwitch()
{
	new src[32], dst[32]
	copy(src, charsmax(src), g_srcItem)
	copy(dst, charsmax(dst), g_dstItem)

	g_entityCount = 0

	if (equal(src, "@all"))
	{
		for (new i = 0; i < sizeof g_items; i++)
		{
			collectEntities("item", g_items[i], 2)
		}
	}
	else
	{
		collectEntities("item", src, 2)
	}

	removeCollected()

	new total = g_entityCount
	
	if (total > 0)
	{
		if (g_deleteOnly)
		{
			client_print(0, print_chat, "[Hot Switch] Deleted %d item spawn(s)", total)
			server_print("[Hot Switch] Deleted %d item spawn(s)", total)
		}
		else
		{
			client_print(0, print_chat, "[Hot Switch] Replaced %d item spawn(s) with %s", total, dst)
			server_print("[Hot Switch] Replaced %d item spawn(s) with %s", total, dst)
		}
	}
	else
	{
		client_print(0, print_console, "No item spawns found on this map")
	}

	if (!g_deleteOnly)
	{
		g_currentBatch = 0
		set_task(0.3, "createNextBatch")
	}
}

public createNextBatch()
{
	new dst[32], dstClass[32], dstAmmo[32]
	copy(dst, charsmax(dst), g_dstWeapon)

	if (g_dstWeapon[0] != 0)
	{
		format(dstClass, charsmax(dstClass), "weapon_%s", dst)
		new dstIdx = getWeaponIndex(dst)
		if (dstIdx >= 0 && strlen(g_weaponAmmo[dstIdx]) > 0)
		{
			copy(dstAmmo, charsmax(dstAmmo), g_weaponAmmo[dstIdx])
		}
		else dstAmmo[0] = 0
	}
	else if (g_dstAmmo[0] != 0)
	{
		format(dstClass, charsmax(dstClass), "ammo_%s", g_dstAmmo)
		dstAmmo[0] = 0
	}
	else if (g_dstItem[0] != 0)
	{
		format(dstClass, charsmax(dstClass), "item_%s", g_dstItem)
		dstAmmo[0] = 0
	}
	else dstClass[0] = 0

	new startIdx = g_currentBatch
	new endIdx = startIdx + 1
	if (endIdx > g_entityCount) endIdx = g_entityCount

	for (new i = startIdx; i < endIdx; i++)
	{
		new ent = g_entityEnt[i]
		new Float:origin[3]
		origin[0] = float(g_entityOrigin[i][0])
		origin[1] = float(g_entityOrigin[i][1])
		origin[2] = float(g_entityOrigin[i][2])

		if (is_valid_ent(ent))
		{
			set_pev(ent, pev_solid, SOLID_NOT)
		}

		new classToCreate[32]
		new ammoClass[32]

		if (g_entityType[i] == 0 && dstAmmo[0] != 0 && g_dstWeapon[0] != 0)
		{
			copy(classToCreate, charsmax(classToCreate), dstClass)
		}
		else if (g_entityType[i] == 1)
		{
			if (g_dstWeapon[0] != 0 && dstAmmo[0] != 0)
			{
				copy(ammoClass, charsmax(ammoClass), dstAmmo)
				copy(classToCreate, charsmax(classToCreate), ammoClass)
			}
			else if (g_dstAmmo[0] != 0)
			{
				copy(classToCreate, charsmax(classToCreate), dstClass)
			}
		}
		else if (g_entityType[i] == 2 && g_dstItem[0] != 0)
		{
			copy(classToCreate, charsmax(classToCreate), dstClass)
		}
		else classToCreate[0] = 0

		if (classToCreate[0] != 0)
		{
			new newEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classToCreate))
			if (is_valid_ent(newEnt))
			{
				engfunc(EngFunc_SetOrigin, newEnt, origin)
				DispatchSpawn(newEnt)
			}
		}
	}

	g_currentBatch++

	if (g_currentBatch < g_entityCount)
	{
		set_task(0.3, "createNextBatch")
		return
	}

	if (g_dstWeapon[0] != 0)
	{
		client_print(0, print_chat, "[Hot Switch] Weapons switched to %s!", dst)
		stripPlayerWeapons()
	}
	else if (g_dstAmmo[0] != 0)
	{
		client_print(0, print_chat, "[Hot Switch] Ammo switched to %s!", g_dstAmmo)
	}
	else if (g_dstItem[0] != 0)
	{
		client_print(0, print_chat, "[Hot Switch] Items switched to %s!", g_dstItem)
	}
}

collectEntities(const prefix[], const name[], type)
{
	new searchClass[32]
	format(searchClass, charsmax(searchClass), "%s_%s", prefix, name)

	new ent = -1
	while ((ent = find_ent_by_class(ent, searchClass)) != 0)
	{
		if (!is_valid_ent(ent)) continue

		new owner = pev(ent, pev_owner)
		if (owner != 0) continue

		if (g_entityCount >= MAX_ENTS) break

		new Float:origin[3]
		pev(ent, pev_origin, origin)

		g_entityEnt[g_entityCount] = ent
		g_entityOrigin[g_entityCount][0] = floatround(origin[0])
		g_entityOrigin[g_entityCount][1] = floatround(origin[1])
		g_entityOrigin[g_entityCount][2] = floatround(origin[2])
		g_entityType[g_entityCount] = type
		g_entityCount++
	}
}

removeCollected()
{
	for (new i = 0; i < g_entityCount; i++)
	{
		new ent = g_entityEnt[i]
		if (is_valid_ent(ent))
		{
			new owner = pev(ent, pev_owner)
			if (owner != 0) continue
			remove_entity(ent)
		}
	}
}

stripPlayerWeapons()
{
	new players[32], pnum
	get_players(players, pnum, "ach")

	for (new i = 0; i < pnum; i++)
	{
		new pid = players[i]
		strip_user_weapons(pid)
		give_item(pid, "weapon_crowbar")
	}
}

getWeaponIndex(const weapon[])
{
	for (new i = 0; i < sizeof g_weapons; i++)
	{
		if (equal(g_weapons[i], weapon)) return i
	}
	return -1
}

bool:isValidAmmo(const ammo[])
{
	for (new i = 0; i < sizeof g_ammos; i++)
	{
		if (equal(g_ammos[i], ammo)) return true
	}
	return false
}

bool:isValidItem(const item[])
{
	for (new i = 0; i < sizeof g_items; i++)
	{
		if (equal(g_items[i], item)) return true
	}
	return false
}

getAmmoShortName(const fullAmmo[], shortName[32])
{
	new len = strlen(fullAmmo)
	if (len > 5)
	{
		copy(shortName, 31, fullAmmo[5])
	}
	else
	{
		copy(shortName, 31, fullAmmo)
	}
}

public cmdSaveMap(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

	g_savedCount = 0
	g_hasSaved = false

	new maxents = entity_count()
	new classname[32]
	new Float:origin[3]
	new ent

	for (ent = 1; ent < maxents; ent++)
	{
		if (!is_valid_ent(ent)) continue

		entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname))
		if (classname[0] == 0) continue

		if (!isGameEntity(classname)) continue

		new owner = pev(ent, pev_owner)
		if (owner != 0) continue

		if (g_savedCount >= MAX_ENTS) break

		pev(ent, pev_origin, origin)

		copy(g_savedClassname[g_savedCount], 31, classname)
		g_savedOrigin[g_savedCount][0] = floatround(origin[0])
		g_savedOrigin[g_savedCount][1] = floatround(origin[1])
		g_savedOrigin[g_savedCount][2] = floatround(origin[2])
		g_savedCount++
	}

	g_hasSaved = true

	client_print(0, print_chat, "[Hot Switch] Saved %d entity spawns", g_savedCount)
	client_print(id, print_console, "[Hot Switch] Saved %d entity spawns", g_savedCount)

	return PLUGIN_HANDLED
}

public cmdResetMap(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

	if (!g_hasSaved || g_savedCount == 0)
	{
		client_print(id, print_console, "No saved spawns found. Run 'hs save' first.")
		return PLUGIN_HANDLED
	}

	new maxents = entity_count()
	new classname[32]

	new entsToRemove[MAX_ENTS]
	new removeCount = 0

	for (new ent = 1; ent < maxents && removeCount < MAX_ENTS; ent++)
	{
		if (!is_valid_ent(ent)) continue

		entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname))
		if (classname[0] == 0) continue

		if (!isGameEntity(classname)) continue

		new owner = pev(ent, pev_owner)
		if (owner != 0) continue

		entsToRemove[removeCount] = ent
		removeCount++
	}

	for (new i = removeCount - 1; i >= 0; i--)
	{
		new ent = entsToRemove[i]
		if (is_valid_ent(ent))
		{
			remove_entity(ent)
		}
	}

	new restored = 0
	for (new i = 0; i < g_savedCount; i++)
	{
		new Float:origin[3]
		origin[0] = float(g_savedOrigin[i][0])
		origin[1] = float(g_savedOrigin[i][1])
		origin[2] = float(g_savedOrigin[i][2])

		new newEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, g_savedClassname[i]))
		if (is_valid_ent(newEnt))
		{
			engfunc(EngFunc_SetOrigin, newEnt, origin)
			DispatchSpawn(newEnt)
			restored++
		}
	}

	client_print(0, print_chat, "[Hot Switch] Reset! Restored %d entity spawns", restored)
	client_print(id, print_console, "[Hot Switch] Reset! Restored %d entity spawns", restored)

	return PLUGIN_HANDLED
}

bool:isGameEntity(const classname[])
{
	if (contain(classname, "weapon_") != -1) return true
	if (contain(classname, "ammo_") != -1) return true
	if (contain(classname, "item_") != -1) return true
	return false
}

public cmdListEntities(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

	new searchArg[32]
	read_argv(2, searchArg, charsmax(searchArg))

	new maxents = entity_count()
	new classname[32]
	new Float:origin[3]
	new ent
	new weaponCount = 0, ammoCount = 0, itemCount = 0

	client_print(id, print_console, "=== All weapon/ammo/item entities on map ===")

	for (ent = 1; ent < maxents; ent++)
	{
		if (!is_valid_ent(ent)) continue

		entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname))
		if (classname[0] == 0) continue

		new matches = 0
		if (contain(classname, "weapon_") != -1) matches = 1
		else if (contain(classname, "ammo_") != -1) matches = 2
		else if (contain(classname, "item_") != -1) matches = 3
		else continue

		if (searchArg[0] != 0 && contain(classname, searchArg) == -1) continue

		pev(ent, pev_origin, origin)
		client_print(id, print_console, "[%d] %s at (%.0f, %.0f, %.0f)", ent, classname, origin[0], origin[1], origin[2])

		if (matches == 1) weaponCount++
		else if (matches == 2) ammoCount++
		else if (matches == 3) itemCount++
	}

	client_print(id, print_console, "--- Summary ---")
	client_print(id, print_console, "Weapons: %d  Ammo: %d  Items: %d  Total: %d", weaponCount, ammoCount, itemCount, weaponCount + ammoCount + itemCount)
	client_print(id, print_console, "Total entities checked: %d", maxents)

	return PLUGIN_HANDLED
}

public cmdListEntitiesSpecific(id, level, cid, const prefix[])
{
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

	new maxents = entity_count()
	new classname[32]
	new Float:origin[3]
	new ent
	new count = 0

	client_print(id, print_console, "=== Entities with prefix '%s' ===", prefix)

	for (ent = 1; ent < maxents; ent++)
	{
		if (!is_valid_ent(ent)) continue

		entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname))
		if (classname[0] == 0) continue
		if (contain(classname, prefix) == -1) continue

		pev(ent, pev_origin, origin)
		client_print(id, print_console, "[%d] %s at (%.0f, %.0f, %.0f)", ent, classname, origin[0], origin[1], origin[2])
		count++
	}

	client_print(id, print_console, "Total: %d", count)

	return PLUGIN_HANDLED
}
