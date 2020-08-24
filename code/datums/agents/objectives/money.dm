/datum/agent_objective/money
	description = ""
	var/money_required = 7500

/datum/agent_objective/money/New(datum/agent/A)
	money_required = rand(5000, 10000)

	. = ..()

/datum/agent_objective/money/generate_objective_body_message()
	return "Cause confusion and disarray of the [MAIN_SHIP_NAME] economy by [SPAN_BOLD("[SPAN_BLUE("amassing")]")] [SPAN_BOLD("[SPAN_RED("[money_required] dollars")]")]."

/datum/agent_objective/money/generate_description()
	description = "Cause confusion and disarray of the [MAIN_SHIP_NAME] economy by amassing [money_required] dollars."

/datum/agent_objective/money/check_completion_round_end()
	. = ..()
	if(!.)
		return FALSE

	var/amount_collected = 0
	for(var/obj/item/I in belonging_to_agent.source_human)
		if(istype(I, /obj/item/storage))
			for(var/obj/item/backpackI in I)
				if(istype(backpackI, /obj/item/spacecash))
					var/obj/item/spacecash/C = backpackI
					amount_collected += C.worth

		if(istype(I, /obj/item/spacecash))
			var/obj/item/spacecash/C = I
			amount_collected += C.worth

	if(amount_collected >= money_required)
		return TRUE

	return FALSE