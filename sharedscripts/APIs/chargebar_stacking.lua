-- Shared registry keeping above head chargebars from overlapping; items register the id at load time in render priority order
POR.ChargeBarRegistry = POR.ChargeBarRegistry or {}

function POR.RegisterChargeBarItem(itemId)
    table.insert(POR.ChargeBarRegistry, itemId)
end

-- Returns how many chargebar items registered before itemId the player also holds, which is the number of slots this bar should be offset upward
function POR.ChargeBarStackIndex(player, itemId)
    local index = 0
    for _, registeredId in ipairs(POR.ChargeBarRegistry) do
        if registeredId == itemId then
            break
        end
        if player:HasCollectible(registeredId) then
            index = index + 1
        end
    end
    return index
end
