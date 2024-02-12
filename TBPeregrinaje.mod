return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`TBPeregrinaje` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("TBPeregrinaje", {
			mod_script       = "scripts/mods/TBPeregrinaje/TBPeregrinaje",
			mod_data         = "scripts/mods/TBPeregrinaje/TBPeregrinaje_data",
			mod_localization = "scripts/mods/TBPeregrinaje/TBPeregrinaje_localization",
		})
	end,
	packages = {
		"resource_packages/TBPeregrinaje/TBPeregrinaje",
	},
}
