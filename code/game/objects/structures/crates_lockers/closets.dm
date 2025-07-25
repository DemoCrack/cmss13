/obj/structure/closet
	name = "closet"
	desc = "It's a basic storage unit."
	icon = 'icons/obj/structures/closet.dmi'
	icon_state = "closed"
	density = TRUE
	layer = BELOW_OBJ_LAYER
	blocks_emissive = EMISSIVE_BLOCK_GENERIC
	var/icon_closed = "closed"
	var/icon_opened = "open"
	var/opened = 0
	var/welded = 0
	var/wall_mounted = 0 //never solid (You can always pass over it)
	health = 100
	var/lastbang
	var/storage_capacity = 30 //This is so that someone can't pack hundreds of items in a locker/crate
							  //then open it in a populated area to crash clients.
	var/open_sound = 'sound/handling/hinge_squeak1.ogg'
	var/close_sound = 'sound/handling/hinge_squeak2.ogg'

	var/material = MATERIAL_METAL

	var/store_items = TRUE
	var/store_mobs = TRUE
	var/fill_from_loc = TRUE //Whether items from the tile are automatically moved inside the closet.
	var/exit_stun = 2 //stun time upon exiting, if at all

	anchored = TRUE //Yep

	var/mob_size = 15

/obj/structure/closet/Initialize()
	. = ..()
	if(!opened && fill_from_loc) // if closed, any item at the crate's loc is put in the contents
		store_items()
	GLOB.closet_list += src
	flags_atom |= USES_HEARING

/obj/structure/closet/Destroy()
	dump_contents()
	GLOB.closet_list -= src
	return ..()

/obj/structure/closet/initialize_pass_flags(datum/pass_flags_container/PF)
	..()
	if (PF)
		PF.flags_can_pass_all = PASS_HIGH_OVER_ONLY|PASS_AROUND

/obj/structure/closet/alter_health()
	return get_turf(src)

/obj/structure/closet/BlockedPassDirs(atom/movable/mover, target_dir)
	if(wall_mounted)
		return NO_BLOCKED_MOVEMENT

	return ..()

/obj/structure/closet/proc/select_gamemode_equipment(gamemode)
	return

/obj/structure/closet/proc/can_open()
	if(src.welded)
		return 0
	return 1

/obj/structure/closet/proc/can_close(mob/user)
	for(var/obj/structure/closet/closet in get_turf(src))
		if(closet != src && !closet.wall_mounted)
			return FALSE
	for(var/mob/living/carbon/xenomorph/xeno in get_turf(src))
		return FALSE
	if(MODE_HAS_MODIFIER(/datum/gamemode_modifier/disable_stripdrag_enemy))
		for(var/mob/living/carbon/human/closed_mob in get_turf(src))
			if((closed_mob.stat == DEAD || closed_mob.health < HEALTH_THRESHOLD_CRIT) && !closed_mob.get_target_lock(user.faction_group) && !(closed_mob.status_flags & PERMANENTLY_DEAD)&& !(closed_mob.status_flags & PERMANENTLY_DEAD))
				return FALSE
	return TRUE

/obj/structure/closet/proc/dump_contents()

	for(var/obj/I in src)
		I.forceMove(loc)

	for(var/mob/M in src)
		M.forceMove(loc)
		if(exit_stun)
			M.apply_effect(exit_stun, STUN) //Action delay when going out of a closet
		if(isliving(M))
			var/mob/living/living_M = M
			if(living_M.mobility_flags & MOBILITY_MOVE)
				M.visible_message(SPAN_WARNING("[M] suddenly gets out of [src]!"),
				SPAN_WARNING("You get out of [src] and get your bearings!"))

/obj/structure/closet/proc/open()
	if(opened)
		return 0

	if(!can_open())
		return 0

	dump_contents()

	UnregisterSignal(src, COMSIG_CLOSET_FLASHBANGED)
	opened = 1
	update_icon()
	playsound(src.loc, open_sound, 15, 1)
	density = FALSE
	return 1

/obj/structure/closet/proc/close(mob/user)
	if(!src.opened)
		return 0
	if(!src.can_close(user))
		return 0

	var/stored_units = 0
	if(store_items)
		stored_units = store_items(stored_units)
	if(store_mobs)
		stored_units = store_mobs(stored_units)
		RegisterSignal(src, COMSIG_CLOSET_FLASHBANGED, PROC_REF(flashbang))

	opened = 0
	update_icon()

	playsound(src.loc, close_sound, 15, 1)
	density = TRUE
	return 1

/obj/structure/closet/proc/store_items(stored_units)
	for(var/obj/item/I in src.loc)
		if(istype(I, /obj/item/explosive/plastic)) //planted c4 may not go in closets
			var/obj/item/explosive/plastic/P = I
			if(P.active)
				continue
		if(istype(I, /obj/item/phone))
			continue
		var/item_size = ceil(I.w_class / 2)
		if(stored_units + item_size > storage_capacity)
			continue
		if(!I.anchored)
			I.forceMove(src)
			stored_units += item_size
	return stored_units

/obj/structure/closet/proc/store_mobs(stored_units)
	for(var/mob/cur_mob in src.loc)
		if(stored_units + mob_size > storage_capacity)
			break
		if(istype (cur_mob, /mob/dead/observer))
			continue
		if(cur_mob.buckled)
			continue
		if(cur_mob.anchored)
			continue

		cur_mob.forceMove(src)
		stored_units += mob_size
	return stored_units

/obj/structure/closet/proc/toggle(mob/living/user)
	user.next_move = world.time + 5
	if(!(src.opened ? src.close(user) : src.open()))
		to_chat(user, SPAN_NOTICE("It won't budge!"))
	return


/obj/structure/closet/proc/take_damage(damage)
	if(health <= 0)
		return

	health = max(health - damage, 0)
	if(health <= 0)
		for(var/atom/movable/movable as anything in src)
			if(!loc)
				break
			movable.forceMove(loc)
		playsound(loc, 'sound/effects/meteorimpact.ogg', 25, 1)
		qdel(src)

// this should probably use dump_contents()
/obj/structure/closet/ex_act(severity)
	switch(severity)
		if(0 to EXPLOSION_THRESHOLD_LOW)
			if(prob(5))
				contents_explosion(severity - EXPLOSION_THRESHOLD_LOW)
				deconstruct(FALSE)
		if(EXPLOSION_THRESHOLD_LOW to EXPLOSION_THRESHOLD_MEDIUM)
			if(prob(50))
				contents_explosion(severity - EXPLOSION_THRESHOLD_LOW)
				deconstruct(FALSE)
		if(EXPLOSION_THRESHOLD_MEDIUM to INFINITY)
			contents_explosion(severity - EXPLOSION_THRESHOLD_LOW)
			deconstruct(FALSE)

/obj/structure/closet/proc/flashbang(datum/source, obj/item/explosive/grenade/flashbang/FB)
	SIGNAL_HANDLER
	for(var/mob/living/C in contents)
		FB.bang(get_turf(FB), C)
	open()

/obj/structure/closet/bullet_act(obj/projectile/Proj)
	take_damage(Proj.damage*0.3)
	if(prob(30))
		playsound(loc, 'sound/effects/metalhit.ogg', 25, 1)

	return TRUE

/obj/structure/closet/attack_animal(mob/living/user)
	if(user.wall_smash)
		visible_message(SPAN_DANGER("[user] destroys [src]."))
		for(var/atom/movable/A as mob|obj in src)
			A.forceMove(src.loc)
		qdel(src)

/obj/structure/closet/attackby(obj/item/W, mob/living/user)
	if(src.opened)
		if(istype(W, /obj/item/grab))
			if(isxeno(user))
				return
			var/obj/item/grab/G = W
			if(G.grabbed_thing)
				src.MouseDrop_T(G.grabbed_thing, user)   //act like they were dragged onto the closet
			return
		if(W.flags_item & ITEM_ABSTRACT)
			return 0
		if(material == MATERIAL_METAL)
			if(iswelder(W))
				if(!HAS_TRAIT(W, TRAIT_TOOL_BLOWTORCH))
					to_chat(user, SPAN_WARNING("You need a stronger blowtorch!"))
					return
				var/obj/item/tool/weldingtool/WT = W
				if(!WT.isOn())
					to_chat(user, SPAN_WARNING("\The [WT] needs to be on!"))
					return
				if(!WT.remove_fuel(0 ,user))
					to_chat(user, SPAN_NOTICE("You need more welding fuel to complete this task."))
					return
				playsound(src, 'sound/items/Welder.ogg', 25, 1)
				if(!do_after(user, 10 * user.get_skill_duration_multiplier(SKILL_CONSTRUCTION), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					return
				new /obj/item/stack/sheet/metal(src.loc)
				for(var/mob/M as anything in viewers(src))
					M.show_message(SPAN_NOTICE("\The [src] has been cut apart by [user] with [WT]."), SHOW_MESSAGE_VISIBLE, "You hear welding.", SHOW_MESSAGE_AUDIBLE)
				qdel(src)
				return
		if(material == MATERIAL_WOOD)
			if(HAS_TRAIT(W, TRAIT_TOOL_CROWBAR))
				playsound(src, 'sound/effects/woodhit.ogg')
				if(!do_after(user, 10 * user.get_skill_duration_multiplier(SKILL_CONSTRUCTION), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
					return
				new /obj/item/stack/sheet/wood(src.loc)
				user.visible_message(SPAN_NOTICE("[user] has pried apart [src] with [W]."), "You pry apart [src].")
				qdel(src)
				return
		user.drop_inv_item_to_loc(W,loc)

	//If we're trying to label a crate, label it, don't open it. The code that lets a hand labeler label crates but not lockers is in misc_tools.dm
	else if(istype(W, /obj/item/tool/hand_labeler))
		return
	else if(istype(W, /obj/item/packageWrap) || istype(W, /obj/item/explosive/plastic))
		return
	else if(iswelder(W))
		if(material != MATERIAL_METAL && material != MATERIAL_PLASTEEL)
			to_chat(user, SPAN_WARNING("You cannot weld [material]!"))
			return FALSE//Can't weld wood/plastic.
		if(!HAS_TRAIT(W, TRAIT_TOOL_BLOWTORCH))
			to_chat(user, SPAN_WARNING("You need a stronger blowtorch!"))
			return FALSE
		var/obj/item/tool/weldingtool/WT = W
		if(!WT.isOn())
			to_chat(user, SPAN_WARNING("\The [WT] needs to be on!"))
			return FALSE
		if(!WT.remove_fuel(0, user))
			to_chat(user, SPAN_NOTICE("You need more welding fuel to complete this task."))
			return FALSE
		playsound(src, 'sound/items/Welder.ogg', 25, 1)
		if(!do_after(user, 10 * user.get_skill_duration_multiplier(SKILL_CONSTRUCTION), INTERRUPT_ALL|BEHAVIOR_IMMOBILE, BUSY_ICON_BUILD))
			return FALSE
		welded = !welded
		update_icon()
		for(var/mob/M as anything in viewers(src))
			M.show_message(SPAN_WARNING("[src] has been [welded?"welded shut":"unwelded"] by [user.name]."), SHOW_MESSAGE_VISIBLE, "You hear welding.", SHOW_MESSAGE_AUDIBLE)
	else
		if(isxeno(user))
			var/mob/living/carbon/xenomorph/opener = user
			src.attack_alien(opener)
			return FALSE
		src.attack_hand(user)
	return TRUE

/obj/structure/closet/MouseDrop_T(atom/movable/O, mob/user)
	if(!opened)
		return
	if(!isturf(O.loc))
		return
	if(user.is_mob_incapacitated())
		return
	if(O.anchored || get_dist(user, src) > 1 || get_dist(user, O) > 1)
		return
	if(!ishuman(user) && !HAS_TRAIT(user, TRAIT_OPPOSABLE_THUMBS))
		return
	if(!isturf(user.loc))
		return
	if(ismob(O))
		var/mob/M = O
		if(M.buckled)
			return
	else if(!istype(O, /obj/item))
		return

	add_fingerprint(user)
	if(user == O)
		if(climbable)
			do_climb(user)
		return
	else
		step_towards(O, loc)
		user.visible_message(SPAN_DANGER("[user] stuffs [O] into [src]!"))



/obj/structure/closet/relaymove(mob/user)
	if(!isturf(src.loc))
		return
	if(user.is_mob_incapacitated(TRUE))
		return
	user.next_move = world.time + 5

	var/obj/item/I = user.get_active_hand()
	if(istype(I) && (I.pry_capable == IS_PRY_CAPABLE_FORCE))
		visible_message(SPAN_DANGER("[user] smashes out of the locker!"))
		playsound(loc, 'sound/effects/metal_crash.ogg', 75)
		qdel(src)
		return

	if(!src.open())
		to_chat(user, SPAN_NOTICE("It won't budge!"))
		if(!lastbang)
			lastbang = 1
			for (var/mob/M in hearers(src, null))
				to_chat(M, text("<FONT size=[]>BANG, bang!</FONT>", max(0, 5 - get_dist(src, M))))
			addtimer(VARSET_CALLBACK(src, lastbang, FALSE), 3 SECONDS)

/obj/structure/closet/attack_hand(mob/living/user)
	if(opened && isxeno(user))
		return // stop xeno closing things
	add_fingerprint(user)
	toggle(user)

/obj/structure/closet/verb/verb_toggleopen()
	set src in oview(1)
	set category = "Object"
	set name = "Toggle Open"

	if(usr.is_mob_incapacitated())
		return

	if(usr.loc == src)
		return

	if(ishuman(usr))
		src.add_fingerprint(usr)
		src.toggle(usr)

/obj/structure/closet/update_icon()//Putting the welded stuff in updateicon() so it's easy to overwrite for special cases (Fridges, cabinets, and whatnot)
	overlays.Cut()
	if(!opened)
		icon_state = icon_closed
		if(welded)
			overlays += "welded"
	else
		icon_state = icon_opened

/obj/structure/closet/hear_talk(mob/M as mob, text, verb, language, italics)
	for (var/atom/A in src)
		if(istype(A,/obj/))
			var/obj/O = A
			O.hear_talk(M, text)
#ifdef OBJECTS_PROXY_SPEECH
			continue
		var/mob/living/TM = A
		if(istype(TM) && TM.stat != DEAD)
			proxy_object_heard(src, M, TM, text, verb, language, italics)
#endif // ifdef OBJECTS_PROXY_SPEECH

/obj/structure/closet/proc/break_open()
	if(!opened)
		welded = 0
		open()

/obj/structure/closet/yautja
	name = "alien closet"
	desc = "A suspicious dark metal alien closet, what horrors can be stored inside?"
	icon = 'icons/obj/structures/machinery/yautja_machines.dmi'
	storage_capacity = 100

/obj/structure/closet/yautja/big
	icon = 'icons/obj/structures/props/hunter/32x32_hunter_props.dmi'
	storage_capacity = 100
