#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>

new const g_weapons[][] = {
	"crowbar", "glock", "python", "mp5", "chaingun", 
	"crossbow", "shotgun", "rpg", "gauss", "egon", 
	"hornetgun", "handgrenade"
}

new const g_weaponAmmo[][] = {
	"",             // crowbar (no ammo)
	"ammo_9mmclip", // glock
	"ammo_357",     // python
	"ammo_9mmclip", // mp5
	"ammo_9mmclip", // chaingun
	"ammo_crossbow", // crossbow
	"ammo_buckshot", // shotgun
	"ammo_rpgclip",  // rpg
	"ammo_gaussclip", // gauss
	"ammo_gaussclip", // egon
	"ammo_hornets",  // hornetgun
	"ammo_argrenades" // handgrenade
}

public plugin_init()
{
	register_plugin("Weapon Switcher", "1.0", "Daniel")
	register_clcmd("ws_change", "cmdWeaponSwitch", ADMIN_BAN, "- Replace weapon spawns: ws_change <weapon1> <weapon2>")
	register_srvcmd("ws_change", "cmdWeaponSwitch", ADMIN_BAN, "- Replace weapon spawns: ws_change <weapon1> <weapon2>")
}

public cmdWeaponSwitch(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED

	new arg1[32], arg2[32]
	read_argv(1, arg1, charsmax(arg1))
	read_argv(2, arg2, charsmax(arg2))

	new sourceIdx = getWeaponIndex(arg1)
	new targetIdx = getWeaponIndex(arg2)

	if (sourceIdx == -1)
	{
		client_print(id, print_console, "Invalid source weapon: %s", arg1)
		return PLUGIN_HANDLED
	}

	if (targetIdx == -1)
	{
		client_print(id, print_console, "Invalid target weapon: %s", arg2)
		return PLUGIN_HANDLED
	}

	new weaponCount = switch_weapons(arg1, arg2)
	new ammoCount = switch_ammo(g_weaponAmmo[sourceIdx], g_weaponAmmo[targetIdx])

	if (weaponCount > 0)
	{
		new msg[128]
		new len = format(msg, charsmax(msg), "[Weapon Switcher] Replaced %d %s spawn(s) with %s", weaponCount, arg1, arg2)
		
		if (ammoCount > 0)
		{
			len += format(msg[len], charsmax(msg) - len, " and %d ammo spawn(s)", ammoCount)
		}
		
		client_print(0, print_chat, msg)
		server_print(msg)
	}
	else
	{
		client_print(id, print_console, "No %s spawns found on this map", arg1)
	}

	return PLUGIN_HANDLED
}

getWeaponIndex(const weapon[])
{
	for (new i = 0; i < sizeof g_weapons; i++)
	{
		if (equal(g_weapons[i], weapon))
			return i
	}
	return -1
}

switch_weapons(const source[], const target[])
{
	new sourceClass[32], targetClass[32]
	format(sourceClass, charsmax(sourceClass), "weapon_%s", source)
	format(targetClass, charsmax(targetClass), "weapon_%s", target)

	new ent = -1, count = 0
	new Float:origin[3], Float:angles[3]
	new spawnflags

	while ((ent = find_ent_by_class(ent, sourceClass)) != 0)
	{
		if (!is_valid_ent(ent))
			continue

		new owner = pev(ent, pev_owner)
		if (owner != 0)
			continue

		pev(ent, pev_origin, origin)
		pev(ent, pev_angles, angles)
		spawnflags = pev(ent, pev_spawnflags)

		new newEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, targetClass))
		
		if (is_valid_ent(newEnt))
		{
			engfunc(EngFunc_SetOrigin, newEnt, origin)
			set_pev(newEnt, pev_angles, angles)
			set_pev(newEnt, pev_spawnflags, spawnflags)
			
			DispatchSpawn(newEnt)
			set_pev(newEnt, pev_solid, SOLID_TRIGGER)
			set_pev(newEnt, pev_movetype, MOVETYPE_TOSS)
			
			count++
		}

		remove_entity(ent)
	}

	return count
}

switch_ammo(const sourceAmmo[], const targetAmmo[])
{
	if (strlen(sourceAmmo) == 0)
		return 0

	new sourceClass[32], targetClass[32]
	format(sourceClass, charsmax(sourceClass), "%s", sourceAmmo)
	
	new targetHasAmmo = strlen(targetAmmo) > 0
	if (targetHasAmmo)
	{
		format(targetClass, charsmax(targetClass), "%s", targetAmmo)
	}

	new ent = -1, count = 0
	new Float:origin[3], Float:angles[3]
	new spawnflags

	while ((ent = find_ent_by_class(ent, sourceClass)) != 0)
	{
		if (!is_valid_ent(ent))
			continue

		new owner = pev(ent, pev_owner)
		if (owner != 0)
			continue

		pev(ent, pev_origin, origin)
		pev(ent, pev_angles, angles)
		spawnflags = pev(ent, pev_spawnflags)

		if (targetHasAmmo)
		{
			new newEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, targetClass))
			
			if (is_valid_ent(newEnt))
			{
				engfunc(EngFunc_SetOrigin, newEnt, origin)
				set_pev(newEnt, pev_angles, angles)
				set_pev(newEnt, pev_spawnflags, spawnflags)
				
				DispatchSpawn(newEnt)
				set_pev(newEnt, pev_solid, SOLID_TRIGGER)
				set_pev(newEnt, pev_movetype, MOVETYPE_TOSS)
				
				count++
			}
		}

		remove_entity(ent)
	}

	return count
}
