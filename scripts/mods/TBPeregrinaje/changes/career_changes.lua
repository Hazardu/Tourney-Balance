local mod = get_mod("TBPeregrinaje")

-- Passive Changes
-- Footknight

mod:modify_talent_buff_template("empire_soldier", "markus_knight_passive", {
    range = 20
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_passive_defence_aura", {
    multiplier = -0.15
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_passive_range", {
    buff_to_add = "markus_knight_passive_defence_aura_range",
	update_func = "activate_buff_on_distance",
	remove_buff_func = "remove_aura_buff",
	range = 40
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_passive_defence_aura_range", {
    multiplier = -0.1
})
mod:add_text("career_passive_desc_es_2a_2", "Aura that reduces damage taken by 15%")
mod:modify_talent_buff_template("empire_soldier", "markus_knight_guard_defence", {
	buff_to_add = "markus_knight_guard_defence_buff",
	stat_buff = "damage_taken",
	update_func = "activate_buff_on_closest_distance",
	remove_buff_func = "remove_aura_buff",
	range = 20
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_guard", {
	buff_to_add = "markus_knight_passive_power_increase_buff",
	stat_buff = "power_level",
	remove_buff_func = "remove_aura_buff",
	icon = "markus_knight_passive_power_increase",
	update_func = "activate_buff_on_closest_distance",
	range = 20
})
mod:modify_talent_buff_template("empire_soldier", "markus_knight_damage_taken_ally_proximity", {
	buff_to_add = "markus_knight_damage_taken_ally_proximity_buff",
	range = 20,
	update_func = "activate_party_buff_stacks_on_ally_proximity",
	chunk_size = 1,
	max_stacks = 3,
	remove_buff_func = "remove_party_buff_stacks"
})
mod:add_buff_function("activate_party_buff_stacks_on_ally_proximity", function (owner_unit, buff, params)
	if not Managers.state.network.is_server then
		return
	end

	local buff_system = Managers.state.entity:system("buff_system")
	local template = buff.template
	local range = 20
	local range_squared = range * range
	local chunk_size = template.chunk_size
	local buff_to_add = template.buff_to_add
	local max_stacks = template.max_stacks
	local side = Managers.state.side.side_by_unit[owner_unit]

	if not side then
		return
	end

	local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
	local own_position = POSITION_LOOKUP[owner_unit]
	local num_nearby_allies = 0
	local allies = #player_and_bot_units

	for i = 1, allies do
		local ally_unit = player_and_bot_units[i]

		if ally_unit ~= owner_unit then
			local ally_position = POSITION_LOOKUP[ally_unit]
			local distance_squared = Vector3.distance_squared(own_position, ally_position)

			if distance_squared < range_squared then
				num_nearby_allies = num_nearby_allies + 1
			end

			if math.floor(num_nearby_allies / chunk_size) == max_stacks then
				break
			end
		end
	end

	if not buff.stack_ids then
		buff.stack_ids = {}
	end

	for i = 1, allies do
		local unit = player_and_bot_units[i]

		if ALIVE[unit] then
			if not buff.stack_ids[unit] then
				buff.stack_ids[unit] = {}
			end

			local unit_position = POSITION_LOOKUP[unit]
			local distance_squared = Vector3.distance_squared(own_position, unit_position)
			local buff_extension = ScriptUnit.extension(unit, "buff_system")

			if range_squared < distance_squared then
				local stack_ids = buff.stack_ids[unit]

				for i = 1, #stack_ids do
					local stack_ids = buff.stack_ids[unit]
					local buff_id = table.remove(stack_ids)

					buff_system:remove_server_controlled_buff(unit, buff_id)
				end
			else
				local num_chunks = math.floor(num_nearby_allies / chunk_size)
				local num_buff_stacks = buff_extension:num_buff_type(buff_to_add)

				if num_buff_stacks < num_chunks then
					local difference = num_chunks - num_buff_stacks
					local stack_ids = buff.stack_ids[unit]

					for i = 1, difference do
						local buff_id = buff_system:add_buff(unit, buff_to_add, unit, true)
						stack_ids[#stack_ids + 1] = buff_id
					end
				elseif num_chunks < num_buff_stacks then
					local difference = num_buff_stacks - num_chunks
					local stack_ids = buff.stack_ids[unit]

					for i = 1, difference do
						local buff_id = table.remove(stack_ids)

						buff_system:remove_server_controlled_buff(unit, buff_id)
					end
				end
			end
		end
	end
end)

mod:modify_talent_buff_template("empire_soldier", "markus_knight_damage_taken_ally_proximity_buff", {
	multiplier = -0.033
})
mod:add_text("markus_knight_damage_taken_ally_proximity_desc_2", "Increases damage protection from Protective Presence by 3.33%% for each nearby ally")


-- Ultimate Changes

-- Footknight
-- Made Widecharge the standard Footknight ult
ActivatedAbilitySettings.es_2[1].cooldown = 40
function mod.career_changes_apply(self)
	mod:hook(CareerAbilityESKnight, "_run_ability", function(func, self)
		func(self)
		local st = self._status_extension
		st.do_lunge.damage.width = 6
		st.do_lunge.damage.interrupt_on_max_hit_mass = false
		local owner_unit = self._owner_unit
		local is_server = self._is_server
		local buff_extension = self._buff_extension
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
		local network_manager = self._network_manager
		local network_transmit = network_manager.network_transmit
		local owner_unit_id = network_manager:unit_game_object_id(owner_unit)
		if talent_extension:has_talent("markus_knight_wide_charge", "empire_soldier", true) then
			local custom_buff_name = "markus_knight_heavy_buff"

			buff_extension:add_buff(custom_buff_name, {
				attacker_unit = owner_unit
			})

			local buff_template_name_id = NetworkLookup.buff_templates[custom_buff_name]

			if is_server then
				network_transmit:send_rpc_clients("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
			else
				network_transmit:send_rpc_server("rpc_add_buff", owner_unit_id, buff_template_name_id, owner_unit_id, 0, false)
			end
		end
	end)
	
	--Fix Hero Time not proccing if ally already disabled
	mod:add_buff_function("markus_knight_movespeed_on_incapacitated_ally", function (owner_unit, buff, params)
		if not Managers.state.network.is_server then
			return
		end

		local side = Managers.state.side.side_by_unit[owner_unit]
		local player_and_bot_units = side.PLAYER_AND_BOT_UNITS
		local num_units = #player_and_bot_units
		local buff_extension = ScriptUnit.extension(owner_unit, "buff_system")
		local buff_system = Managers.state.entity:system("buff_system")
		local template = buff.template
		local buff_to_add = template.buff_to_add
		local disabled_allies = 0

		for i = 1, num_units, 1 do
			local unit = player_and_bot_units[i]
			local status_extension = ScriptUnit.extension(unit, "status_system")
			local is_disabled = status_extension:is_disabled()

			if is_disabled then
				disabled_allies = disabled_allies + 1
			end
		end

		if not buff.disabled_allies then
			buff.disabled_allies = 0
		end

		if buff_extension:has_buff_type(buff_to_add) then
			if disabled_allies <= buff.disabled_allies then
				local buff_id = buff.buff_id

				if buff_id then
					buff_system:remove_server_controlled_buff(owner_unit, buff_id)

					buff.buff_id = nil
				end
			end
		elseif disabled_allies > 0 and disabled_allies > buff.disabled_allies then
			buff.buff_id = buff_system:add_buff(owner_unit, buff_to_add, owner_unit, true)
		end

		buff.disabled_allies = disabled_allies
	end)



	-- Grail Knight Changes
	ActivatedAbilitySettings.es_4[1].cooldown = 60
	mod:add_text("markus_questing_knight_crit_can_insta_kill_desc", "Critical Strikes instantly slay enemies if their current health is less than 3 times the amount of damage of the Critical Strike. Half effect versus Lords and Monsters.")
	mod:modify_talent_buff_template("empire_soldier", "markus_questing_knight_crit_can_insta_kill",  {
		damage_multiplier = 4
	})
	local side_quest_challenge_gs = {
		reward = "markus_questing_knight_passive_strength_potion",
		type = "kill_enemies",
		amount = {
			1,
			100,
			125,
			150,
			175,
			200,
			250,
			250
		}
	}

	-- mod:hook_origin(PassiveAbilityQuestingKnight, "_get_side_quest_challenge", function(self)
	-- 	local side_quest_challenge = side_quest_challenge_gs

	-- 	return side_quest_challenge
	-- end)

	--Handmaiden
	--CareerSettings.we_maidenguard.attributes.max_hp = 150
	-- table.insert(PassiveAbilitySettings.we_2.buffs, "kerillian_maidenguard_passive_damage_reduction")
	-- mod:add_talent_buff_template("wood_elf", "kerillian_maidenguard_passive_damage_reduction", {
	-- 	stat_buff = "damage_taken",
	-- 	multiplier = -0.3
	-- })
	-- PassiveAbilitySettings.we_2.perks = {
	-- 	{
	-- 		display_name = "career_passive_name_we_2b",
	-- 		description = "career_passive_desc_we_2b_2"
	-- 	},
	-- 	{
	-- 		display_name = "career_passive_name_we_2c",
	-- 		description = "career_passive_desc_we_2c_2"
	-- 	},
	-- 	{
	-- 		display_name = "rebaltourn_career_passive_name_we_2d",
	-- 		description = "rebaltourn_career_passive_desc_we_2d_2"
	-- 	}
	-- }
	-- mod:add_text("rebaltourn_career_passive_name_we_2d", "Bendy")
	-- mod:add_text("rebaltourn_career_passive_desc_we_2d_2", "Reduces damage taken by 30%.")

	mod:modify_talent_buff_template("wood_elf", "kerillian_maidenguard_passive_stamina_regen_aura", {
		range = 20
	})

	--Ult hitbox
	mod:hook(CareerAbilityWEMaidenGuard, "_run_ability", function (func, self, ...)
		func(self, ...)

		local owner_unit = self._owner_unit
		local talent_extension = ScriptUnit.extension(owner_unit, "talent_system")
		-- local bleed = talent_extension:has_talent("kerillian_maidenguard_activated_ability_damage")

		-- if bleed then
		-- 	local status_extension = self._status_extension
		-- 	-- hitbox is a rectangular cube / cuboid with given width, height and length, and offset_forward changes its position relative to character's
		-- 	status_extension.do_lunge.damage.width = 1.5    --1.5    --width of hitbox
		-- 	status_extension.do_lunge.damage.depth_padding = 0.4   --0.4    --length of hitbox
		-- 	status_extension.do_lunge.damage.offset_forward = 0   --0    --position of hitbox
		-- else
			local status_extension = self._status_extension
			-- hitbox is a rectangular cube / cuboid with given width, height and length, and offset_forward changes its position relative to character's
			status_extension.do_lunge.damage.width = 6.0    --1.5    --width of hitbox
			status_extension.do_lunge.damage.depth_padding = 6.0   --0.4    --length of hitbox
			status_extension.do_lunge.damage.offset_forward = 6.0   --0    --position of hitbox
		--end
	end)

	--Sister of the Thorn
	-----------------------------------------
	-- PEREGRINAJE COMMENT
	-- SOTT is already changed by a great deal in pere, might as well leave it as is, no nerf

	ActivatedAbilitySettings.we_thornsister[1].cooldown = 60
	mod:modify_talent_buff_template("wood_elf", "kerillian_thorn_sister_passive_temp_health_funnel_aura_buff", {
		multiplier = 0.20
	})

	-- mod:hook_origin(PassiveAbilityThornsister, "_update_extra_abilities_info", function(self, talent_extension)
	--     if not talent_extension then
	--         return
	--     end

	--     local career_ext = self._career_extension

	--     if not career_ext then
	--         return
	--     end

	--     local max_uses = self._ability_init_data.max_stacks

	--     if talent_extension:has_talent("kerillian_double_passive") then
	--         max_uses = max_uses + 1
	--     end

	--     career_ext:update_extra_ability_uses_max(max_uses)

	--     local cooldown = self._ability_init_data.cooldown

	--     if talent_extension:has_talent("kerillian_thorn_sister_faster_passive") then
	--         cooldown = cooldown * 0.75
	--     end

	--     career_ext:update_extra_ability_charge(cooldown)
	-- end)

	-- local WALL_TYPES = table.enum("default", "bleed")
	-- local UNIT_NAMES = {
	-- 	default = "units/beings/player/way_watcher_thornsister/abilities/ww_thornsister_thorn_wall_01",
	-- 	bleed = "units/beings/player/way_watcher_thornsister/abilities/ww_thornsister_thorn_wall_01_bleed"
	-- }

	-- SpawnUnitTemplates.thornsister_thorn_wall_unit = {
	-- 	spawn_func = function (source_unit, position, rotation, state_int, group_spawn_index)
	-- 		local UNIT_NAME = UNIT_NAMES[WALL_TYPES.default]
	-- 		local UNIT_TEMPLATE_NAME = "thornsister_thorn_wall_unit"
	-- 		local wall_index = state_int
	-- 		local despawn_sound_event = "career_ability_kerillian_sister_wall_disappear"
	-- 		local life_time = 6
	-- 		local area_damage_params = {
	-- 			aoe_dot_damage = 0,
	-- 			radius = 0.3,
	-- 			area_damage_template = "we_thornsister_thorn_wall",
	-- 			invisible_unit = false,
	-- 			nav_tag_volume_layer = "temporary_wall",
	-- 			create_nav_tag_volume = true,
	-- 			aoe_init_damage = 0,
	-- 			damage_source = "career_ability",
	-- 			aoe_dot_damage_interval = 0,
	-- 			damage_players = false,
	-- 			source_attacker_unit = source_unit,
	-- 			life_time = life_time
	-- 		}
	-- 		local props_params = {
	-- 			life_time = life_time,
	-- 			owner_unit = source_unit,
	-- 			despawn_sound_event = despawn_sound_event,
	-- 			wall_index = wall_index
	-- 		}
	-- 		local health_params = {
	-- 			health = 20
	-- 		}
	-- 		local buffs_to_add = nil
	-- 		local source_talent_extension = ScriptUnit.has_extension(source_unit, "talent_system")

	-- 		if source_talent_extension then
	-- 			if source_talent_extension:has_talent("kerillian_thorn_sister_tanky_wall") then
	-- 				local life_time_mult = 1
	-- 				local life_time_bonus = 4.2
	-- 				area_damage_params.life_time = area_damage_params.life_time * life_time_mult + life_time_bonus
	-- 				props_params.life_time = 6 /10 *(props_params.life_time * life_time_mult + life_time_bonus)
	-- 			elseif source_talent_extension:has_talent("kerillian_thorn_sister_debuff_wall") then
	-- 				local life_time_mult = 0.17
	-- 				local life_time_bonus = 0
	-- 				area_damage_params.create_nav_tag_volume = false
	-- 				area_damage_params.life_time = area_damage_params.life_time * life_time_mult + life_time_bonus
	-- 				props_params.life_time = props_params.life_time * life_time_mult + life_time_bonus
	-- 				UNIT_NAME = UNIT_NAMES[WALL_TYPES.bleed]
	-- 			end
	-- 		end

	-- 		local extension_init_data = {
	-- 			area_damage_system = area_damage_params,
	-- 			props_system = props_params,
	-- 			health_system = health_params,
	-- 			death_system = {
	-- 				death_reaction_template = "thorn_wall",
	-- 				is_husk = false
	-- 			},
	-- 			hit_reaction_system = {
	-- 				is_husk = false,
	-- 				hit_reaction_template = "level_object"
	-- 			}
	-- 		}
	-- 		local wall_unit = Managers.state.unit_spawner:spawn_network_unit(UNIT_NAME, UNIT_TEMPLATE_NAME, extension_init_data, position, rotation)
	-- 		local random_rotation = Quaternion(Vector3.up(), math.random() * 2 * math.pi - math.pi)

	-- 		Unit.set_local_rotation(wall_unit, 0, random_rotation)

	-- 		local buff_extension = ScriptUnit.has_extension(wall_unit, "buff_system")

	-- 		if buff_extension and buffs_to_add then
	-- 			for i = 1, #buffs_to_add do
	-- 				buff_extension:add_buff(buffs_to_add[i])
	-- 			end
	-- 		end

	-- 		local thorn_wall_extension = ScriptUnit.has_extension(wall_unit, "props_system")

	-- 		if thorn_wall_extension then
	-- 			thorn_wall_extension.group_spawn_index = group_spawn_index
	-- 		end
	-- 	end
	-- }

	-- mod:add_text("kerillian_thorn_sister_tanky_wall_desc_2", "Increase the width of the Thorn Wall.")
	-- mod:add_text("kerillian_thorn_sister_faster_passive_desc", "Reduce the cooldown of Radiance by 25%%, taking damage sets the cooldown back 2 seconds.")

	--Waystalker
	ActivatedAbilitySettings.we_3[1].cooldown = 60
	local sniper_dropoff_ranges = {
		dropoff_start = 60,
		dropoff_end = 90
	}
	DamageProfileTemplates.arrow_sniper_ability_piercing.max_friendly_damage = 30
	DamageProfileTemplates.arrow_sniper_trueflight = {
		charge_value = "projectile",
		no_stagger_damage_reduction_ranged = true,
		critical_strike = {
			attack_armor_power_modifer = {
				1.5,
				1,
				1,
				0.25,
				1,
				0.6
			},
			impact_armor_power_modifer = {
				1,
				1,
				0,
				1,
				1,
				1
			}
		},
		armor_modifier_near = {
			attack = {
				1.5,
				1,
				1,
				0.25,
				1,
				0.6
			},
			impact = {
				1,
				1,
				0,
				0,
				1,
				1
			}
		},
		armor_modifier_far = {
			attack = {
				1.5,
				1,
				2,
				0.25,
				1,
				0.6
			},
			impact = {
				1,
				1,
				0,
				0,
				1,
				0
			}
		},
		cleave_distribution = {
			attack = 0.375,
			impact = 0.375
		},
		default_target = {
			boost_curve_coefficient_headshot = 2.5,
			boost_curve_type = "ninja_curve",
			boost_curve_coefficient = 0.75,
			attack_template = "arrow_sniper",
			power_distribution_near = {
				attack = 0.5,
				impact = 0.3
			},
			power_distribution_far = {
				attack = 0.5,
				impact = 0.25
			},
			range_dropoff_settings = sniper_dropoff_ranges
		},
		max_friendly_damage = 0
	}
	Weapons.kerillian_waywatcher_career_skill_weapon.actions.action_career_hold.prioritized_breeds = {
		skaven_warpfire_thrower = 1,
		chaos_vortex_sorcerer = 1,
		skaven_gutter_runner = 1,
		skaven_pack_master = 1,
		skaven_poison_wind_globadier = 1,
		chaos_corruptor_sorcerer = 1,
		skaven_ratling_gunner = 1,
		beastmen_standard_bearer = 1,
	}

	--Removed bloodshot and ult interaction
	-- mod:hook_origin(ActionCareerWEWaywatcher, "client_owner_post_update", function (self, dt, t, world, can_damage)
	--     local current_action = self.current_action

	-- 	if self.state == "waiting_to_shoot" and self.time_to_shoot <= t then
	-- 		self.state = "shooting"
	-- 	end

	-- 	if self.state == "shooting" then
	-- 		local has_extra_shots = self:_update_extra_shots(self.owner_buff_extension, 1)
	-- 		local add_spread = not self.extra_buff_shot

	-- 		self:fire(current_action, add_spread)

	-- 		if has_extra_shots and has_extra_shots > 1 then
	-- 			self.state = "waiting_to_shoot"
	-- 			self.time_to_shoot = t + 0.1
	-- 			self.extra_buff_shot = true
	-- 		else
	-- 			self.state = "shot"
	-- 		end

	-- 		local first_person_extension = self.first_person_extension

	-- 		if self.current_action.reset_aim_on_attack then
	-- 			first_person_extension:reset_aim_assist_multiplier()
	-- 		end

	-- 		local fire_sound_event = self.current_action.fire_sound_event

	-- 		if fire_sound_event then
	-- 			local play_on_husk = self.current_action.fire_sound_on_husk

	-- 			first_person_extension:play_hud_sound_event(fire_sound_event, nil, play_on_husk)
	-- 		end

	-- 		if self.current_action.extra_fire_sound_event then
	-- 			local position = POSITION_LOOKUP[self.owner_unit]

	-- 			WwiseUtils.trigger_position_event(self.world, self.current_action.extra_fire_sound_event, position)
	-- 		end
	-- 	end
	-- end)

	-- mod:add_proc_function("kerillian_waywatcher_consume_extra_shot_buff", function (player, buff, params)
	--     local is_career_skill = params[5]
	--     local should_consume_shot = nil

	--     if is_career_skill == "RANGED_ABILITY" or is_career_skill == nil then
	--         should_consume_shot = false
	--     else
	--         should_consume_shot = true
	--     end

	--     return should_consume_shot
	-- end)

	-- Bounty Hunter
	table.insert(PassiveAbilitySettings.wh_2.buffs, "victor_bountyhunter_activate_passive_on_melee_kill")


	-----------------------------------------
	-- Already in pere



	-- Battle Wizard Changes
	-- ActivatedAbilitySettings.bw_2[1].cooldown = 60

	-- --Firetrail nerf (Fatshark please)
	-- local buff_perks = require("scripts/unit_extensions/default_player_unit/buffs/settings/buff_perk_names")
	-- mod:add_buff_template("sienna_adept_ability_trail", {
	--     leave_linger_time = 1.5,
	--     name = "sienna_adept_ability_trail",
	--     end_flow_event = "smoke",
	--     start_flow_event = "burn",
	--     on_max_stacks_overflow_func = "reapply_buff",
	--     apply_buff_func = "start_dot_damage",
	--     update_start_delay = 0.25,
	--     death_flow_event = "burn_death",
	--     time_between_dot_damages = 0.75,
	--     damage_type = "burninating",
	--     damage_profile = "burning_dot",
	--     update_func = "apply_dot_damage",
	--     max_stacks = 1,
	--     perks = { buff_perks.burning }
	-- })
	-- --Firebomb fix
	-- mod:add_buff_template("burning_dot_fire_grenade", {
	-- 	duration = 6,
	-- 	name = "burning dot",
	-- 	end_flow_event = "smoke",
	-- 	start_flow_event = "burn",
	-- 	death_flow_event = "burn_death",
	-- 	 update_start_delay = 0.75,
	-- 	apply_buff_func = "start_dot_damage",
	-- 	time_between_dot_damages = 1,
	-- 	damage_type = "burninating",
	-- 	damage_profile = "burning_dot_firegrenade",
	-- 	update_func = "apply_dot_damage",
	-- 	perks = { buff_perks.burning }
	-- })

	-- DamageProfileTemplates.burning_dot_firegrenade.default_target.armor_modifier.attack[6] = 0.25

	--Unchained
	PlayerCharacterStateOverchargeExploding.on_exit = function (self, unit, input, dt, context, t, next_state)
		if not Managers.state.network:game() or not next_state then
			return
		end

		CharacterStateHelper.play_animation_event(unit, "cooldown_end")
		CharacterStateHelper.play_animation_event_first_person(self.first_person_extension, "cooldown_end")

		local career_extension = ScriptUnit.extension(unit, "career_system")
		local career_name = career_extension:career_name()

		if self.falling and next_state ~= "falling" then
			ScriptUnit.extension(unit, "whereabouts_system"):set_no_landing()
		end
	end

	--Explosion kill credit fix
	mod:hook_safe(PlayerProjectileHuskExtension, "init", function(self, extension_init_data)
		self.owner_unit = extension_init_data.owner_unit
	end)
end