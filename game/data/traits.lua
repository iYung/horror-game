-- Traits
-- Monster trait definitions. Each trait has a point cost drawn from the run's budget.
-- Traits are rolled in PlanningScene (greedy shuffle) and passed to Monster.new().
-- Each trait appears at most once per run.
--
-- Costs:  sight=2, speed=1, smell=1, hearing=1  (max budget is 7)
--
-- traits.all  — flat ordered list for iteration and shuffling during trait rolling
-- traits.<id> — direct access by key
--
-- The apply() stub on each trait is unused at runtime; behaviour is implemented
-- directly in monster.lua based on self.has_<traitname> flags set in Monster.new().

local traits = {}

traits.sight = {
    id    = "sight",
    name  = "Keen Sight",
    cost  = 2,
    apply = function(monster) end,
}

traits.speed = {
    id    = "speed",
    name  = "Swift",
    cost  = 1,
    apply = function(monster) end,
}

traits.smell = {
    id    = "smell",
    name  = "Sharp Smell",
    cost  = 1,
    apply = function(monster) end,
}

traits.hearing = {
    id    = "hearing",
    name  = "Acute Hearing",
    cost  = 1,
    apply = function(monster) end,
}

traits.all = {
    traits.sight,
    traits.speed,
    traits.smell,
    traits.hearing,
}

return traits
