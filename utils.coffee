exports.name_to_emoji = (name) ->
    return name.toLowerCase().replace(/\ \(.*\)$/, '').replace(/[ -\/]/g, '').replace(/bomb/g, 'xbomb')

exports.ship_to_icon = (pilot) ->
    return ":#{exports.name_to_emoji(pilot.ship)}:"

exports.faction_to_emoji = (faction) ->
    switch faction
        when 'Scum and Villainy' then return ':scum:'
        when 'Rebel Alliance' then return ':rebel:'
        when 'Galactic Empire' then return ':empire:'
        when 'Galactic Empire' then return ':empire:'
        when 'Resistance' then return ':resistance:'
        when 'First Order' then return ':first_order:'