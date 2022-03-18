local mod = get_mod("TourneyBalance")

-- Text Localization
local _language_id = Application.user_setting("language_id")
local _localization_database = {}
mod._quick_localize = function (self, text_id)
    local mod_localization_table = _localization_database
    if mod_localization_table then
        local text_translations = mod_localization_table[text_id]
        if text_translations then
            return text_translations[_language_id] or text_translations["en"]
        end
    end
end
function mod.add_text(self, text_id, text)
    if type(text) == "table" then
        _localization_database[text_id] = text
    else
        _localization_database[text_id] = {
            en = text
        }
    end
end
mod:hook("Localize", function(func, text_id)
    local str = mod:_quick_localize(text_id)
    if str then return str end
    return func(text_id)
end)
NewDamageProfileTemplates = NewDamageProfileTemplates or {}
function mod:add_buff(buff_name, buff_data)
    local new_buff = {
        buffs = {
            merge({ name = buff_name }, buff_data),
        },
    }
    BuffTemplates[buff_name] = new_buff
    local index = #NetworkLookup.buff_templates + 1
    NetworkLookup.buff_templates[index] = buff_name
    NetworkLookup.buff_templates[buff_name] = index
end

-- THP & Stagger Talent Functions & Changes
mod:dofile("scripts/mods/TourneyBalance/changes/thp_stagger_changes")

-- Talent Changes
mod:dofile("scripts/mods/TourneyBalance/changes/talent_changes")

-- Weapon Changes
mod:dofile("scripts/mods/TourneyBalance/changes/weapon_changes")

-- Career Changes (Passives, Ultimates, etc.)
mod:dofile("scripts/mods/TourneyBalance/changes/career_changes")

-- on_remove_stack_down
--mod:hook_origin(BuffExtension, "remove_buff", function (self, id, skip_net_sync)
--	local buffs = self._buffs
--	local num_buffs = #buffs
--	local end_time = Managers.time:time("game")
--	local num_buffs_removed = 0
--	local i = 1
--	buff_extension_function_params.t = end_time
--	buff_extension_function_params.end_time = end_time
--
--	while i <= num_buffs do
--		local buff = buffs[i]
--		local template = buff.template
--		buff_extension_function_params.bonus = buff.bonus
--		buff_extension_function_params.multiplier = buff.multiplier
--		buff_extension_function_params.value = buff.value
--		buff_extension_function_params.attacker_unit = buff.attacker_unit
--
--		if (id and buff.id == id) or (buff.parent_id and id and buff.parent_id == id) then
--			local on_remove_stack_down = template.on_remove_stack_down
--			if on_remove_stack_down then
--                self:_remove_sub_buff(buff, i, buff_extension_function_params, false)
--
--				local new_buff_count = #buffs
--				num_buffs_removed = num_buffs_removed + num_buffs - new_buff_count
--				num_buffs = new_buff_count
--                self._buffs[i].start_time = Managers.time:time("game")
--            else
--				self:_remove_sub_buff(buff, i, buff_extension_function_params, false)
--
--				local new_buff_count = #buffs
--				num_buffs_removed = num_buffs_removed + num_buffs - new_buff_count
--				num_buffs = new_buff_count
--			end
--		else
--			i = i + 1
--		end
--	end
--
--	if num_buffs == 0 then
--		Managers.state.entity:system("buff_system"):set_buff_ext_active(self._unit, false)
--	end
--
--	if not skip_net_sync then
--		self:_remove_buff_synced(id)
--	end
--
--	self:_free_sync_id(id)
--
--	return num_buffs_removed
--end)
--mod:hook_origin(BuffExtension, "update", function (self, unit, input, dt, context, t)
--	local world = self.world
--	local buffs = self._buffs
--	local unit = self._unit
--	local num_buffs = #buffs
--	local i = 1
--	local buff_extension_function_params = buff_extension_function_params
--	buff_extension_function_params.t = t
--	local queue = self._remove_buff_queue
--
--	if queue then
--		self._remove_buff_queue = nil
--
--		for i = 1, #queue, 1 do
--			self:remove_buff(queue[i])
--		end
--	end
--
--	local on_remove_stack_down_done = {}
--
--	while i <= num_buffs do
--		local buff = buffs[i]
--		local template = buff.template
--		local end_time = buff.duration and buff.start_time + buff.duration
--		buff_extension_function_params.bonus = buff.bonus
--		buff_extension_function_params.multiplier = buff.multiplier
--		buff_extension_function_params.value = buff.value
--		buff_extension_function_params.end_time = end_time
--		buff_extension_function_params.attacker_unit = buff.attacker_unit
--		buff_extension_function_params.source_attacker_unit = buff.source_attacker_unit
--
--		if end_time and end_time <= t then
--            local on_remove_stack_down = template.on_remove_stack_down
--            local buff_name = template.name
--            if on_remove_stack_down and on_remove_stack_down_done[buff_name] == nil then
--                local current_stacks = self:num_buff_type(buff_name)
--
--                self:_remove_sub_buff(buff, i, buff_extension_function_params, true)
--                on_remove_stack_down_done[buff_name] = true
--
--                if current_stacks == 1 then
--                    if template.buff_after_delay and not buff.aborted then
--                        local delayed_buff_name = buff.delayed_buff_name
--
--                        if buff.delayed_buff_params then
--                            local delayed_buff_params = buff.delayed_buff_params
--
--                            self:add_buff(delayed_buff_name, delayed_buff_params)
--                        else
--                            self:add_buff(delayed_buff_name)
--                        end
--                    end
--                end
--            elseif on_remove_stack_down and on_remove_stack_down_done[buff_name] then
--                buff.start_time = t
--            else
--				self:_remove_sub_buff(buff, i, buff_extension_function_params, true)
--
--				if template.buff_after_delay and not buff.aborted then
--					local delayed_buff_name = buff.delayed_buff_name
--
--					if buff.delayed_buff_params then
--						local delayed_buff_params = buff.delayed_buff_params
--
--						self:add_buff(delayed_buff_name, delayed_buff_params)
--					else
--						self:add_buff(delayed_buff_name)
--					end
--				end
--            end
--		else
--			local update_func = template.update_func
--
--			if update_func then
--				local next_update_t = buff._next_update_t
--
--				if not next_update_t then
--					next_update_t = t + (buff.template.update_start_delay or 0)
--					buff._next_update_t = next_update_t
--				end
--
--				if not next_update_t or next_update_t <= t then
--					local time_into_buff = t - buff.start_time
--					local time_left_on_buff = end_time and end_time - t
--					buff_extension_function_params.time_into_buff = time_into_buff
--					buff_extension_function_params.time_left_on_buff = time_left_on_buff
--
--					BuffFunctionTemplates.functions[update_func](unit, buff, buff_extension_function_params, world)
--
--					buff._next_update_t = t + (buff.template.update_frequency or 0)
--				end
--			end
--
--			i = i + 1
--		end
--
--		num_buffs = #buffs
--	end
--
--	if num_buffs == 0 then
--		Managers.state.entity:system("buff_system"):set_buff_ext_active(unit, false)
--	end
--end)
--

local function updateValues()
	for _, buffs in pairs(TalentBuffTemplates) do
		table.merge_recursive(BuffTemplates, buffs)
	end

	return

end

--Add the new templates to the DamageProfile templates
--Setup proper linkin in NetworkLookup
for key, _ in pairs(NewDamageProfileTemplates) do
    i = #NetworkLookup.damage_profiles + 1
    NetworkLookup.damage_profiles[i] = key
    NetworkLookup.damage_profiles[key] = i
end
--Merge the tables together
table.merge_recursive(DamageProfileTemplates, NewDamageProfileTemplates)
--Do FS things
for name, damage_profile in pairs(DamageProfileTemplates) do
	if not damage_profile.targets then
		damage_profile.targets = {}
	end

	fassert(damage_profile.default_target, "damage profile [\"%s\"] missing default_target", name)

	if type(damage_profile.critical_strike) == "string" then
		local template = PowerLevelTemplates[damage_profile.critical_strike]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.critical_strike)

		damage_profile.critical_strike = template
	end

	if type(damage_profile.cleave_distribution) == "string" then
		local template = PowerLevelTemplates[damage_profile.cleave_distribution]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.cleave_distribution)

		damage_profile.cleave_distribution = template
	end

	if type(damage_profile.armor_modifier) == "string" then
		local template = PowerLevelTemplates[damage_profile.armor_modifier]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.armor_modifier)

		damage_profile.armor_modifier = template
	end

	if type(damage_profile.default_target) == "string" then
		local template = PowerLevelTemplates[damage_profile.default_target]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.default_target)

		damage_profile.default_target = template
	end

	if type(damage_profile.targets) == "string" then
		local template = PowerLevelTemplates[damage_profile.targets]

		fassert(template, "damage profile [\"%s\"] has no corresponding template defined in PowerLevelTemplates. Wanted template name is [\"%s\"] ", name, damage_profile.targets)

		damage_profile.targets = template
	end
end

local no_damage_templates = {}

for name, damage_profile in pairs(DamageProfileTemplates) do
	local no_damage_name = name .. "_no_damage"

	if not DamageProfileTemplates[no_damage_name] then
		local no_damage_template = table.clone(damage_profile)

		if no_damage_template.targets then
			for _, target in ipairs(no_damage_template.targets) do
				if target.power_distribution then
					target.power_distribution.attack = 0
				end
			end
		end

		if no_damage_template.default_target.power_distribution then
			no_damage_template.default_target.power_distribution.attack = 0
		end

		no_damage_templates[no_damage_name] = no_damage_template
	end
end

DamageProfileTemplates = table.merge(DamageProfileTemplates, no_damage_templates)

mod.on_enabled = function (self)
	mod:echo("Tourney balance enabled")
	updateValues()

	return
end
