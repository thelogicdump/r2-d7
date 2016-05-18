exportObj = require('./cards-combined')
exportObj.cardLoaders.English()

BotKit = require('botkit')
controller = BotKit.slackbot({debug: false})
bot = controller.spawn({token: process.env.SLACK_TOKEN})
bot.startRTM((err, bot, payload) ->
    if err
        throw new Error('Could not connect to slack!')
)

name_to_emoji = (name) ->
    return name.toLowerCase().replace(/[ -\/]/g, '')

ship_to_icon = (pilot) ->
    return ":#{name_to_emoji(pilot.ship)}:"

faction_to_emoji = (faction) ->
    switch faction
        when 'Scum and Villainy' then return ':scum:'
        when 'Rebel Alliance' then return ':rebel:'
        when 'Galactic Empire' then return ':empire:'
        when 'Galactic Empire' then return ':empire:'
        when 'Resistance' then return ':resistance:'
        when 'First Order' then return ':first_order:'


# For some reason there's a > at the end of the message
controller.hears('geordanr\.github\.io\/xwing\/\?(.*)>$', ["ambient"], (bot, message) ->
    pieces = message.match[1].split('&amp;')
    serialized = pieces[1].split('=')[1]
    if not /v4!s!/.test(serialized)
        return bot.reply(message, "I don't understand URLs before v4.")

    serialized = serialized.slice(5)
    ships = serialized.split(';')
    faction = faction_to_emoji(decodeURI(pieces[0].split('=')[1]))
    output = ["*#{decodeURI(pieces[2].split('=')[1])}* #{faction}"]
    total_points = 0
    for ship in ships
        if not ship then continue
        points = 0
        ship = ship.split(':')
        pilot = exportObj.pilotsById[ship[0]]
        points += pilot.points
        upgrades = []

        add_upgrade = (upgrade) ->
            if upgrade is undefined
                return
            upgrades.push(upgrade.name)
            points += upgrade.points

        # Upgrade : Titles : Modifications : Extra Slots
        for upgrade_id in ship[1].split(',')
            upgrade_id = parseInt(upgrade_id)
            add_upgrade(exportObj.upgradesById[upgrade_id])
        for title_id in ship[2].split(',')
            title_id = parseInt(title_id)
            add_upgrade(exportObj.titlesById[title_id])
        for mod_id in ship[3].split(',')
            mod_id = parseInt(mod_id)
            add_upgrade(exportObj.modificationsById[mod_id])
        for extra in ship[4].split(',')
            extra = extra.split('.')
            extra_id = parseInt(extra[1])
            switch extra[0].toLowerCase()
                when 'u'
                    # Hacked support for Tie/X1
                    upgrade = exportObj.upgradesById[extra_id]
                    if upgrade.slot == 'System' and 'TIE/x1' in upgrades
                        points -= Math.min(4, upgrade.points)
                    add_upgrade(upgrade)
                when 't' then add_upgrade(exportObj.titlesById[extra_id])
                when 'm' then add_upgrade(exportObj.modificationsById[extra_id])

        output.push("_#{pilot.name}_ #{ship_to_icon(pilot)}: #{upgrades.join(', ')} *[#{points}]*")
        total_points += points

    output[0] += " *[#{total_points}]*"
    return bot.reply(message, output.join('\n'))
)

fixIcons = (data) ->
    if data.text?
        data.text = data.text
            .replace(/<i class="xwing-miniatures-font xwing-miniatures-font-/g, ':')
            .replace(/"><\/i>/g, ':')
            .replace(/:bomb:/g, ':xbomb:')  # bomb is already an emoji
            .replace(/<br \/><br \/>/g, '\n')
            .replace(/<strong>/g, '*')
            .replace(/<\/strong>/g, '*')
            .replace(/<em>/g, '')
            .replace(/<\/em>/g, '')
            .replace(/<span class="card-restriction">/g, '_')
            .replace(/<\/span>/g, '_')

strip_name = (name) ->
    return name.toLowerCase().replace(/["]/g, '').replace(/\ \(.*\)$/, '')

# Build a lookup object
card_lookup = {}
add_card = (data) ->
    name = strip_name(data.name)
    card_lookup[name] = card_lookup[name] || []
    card_lookup[name].push(data)
for upgrade_name, upgrade of exportObj.upgrades
    fixIcons(upgrade)
    add_card(upgrade)
for modification_name, modification of exportObj.modifications
    modification.slot = 'Modification'
    fixIcons(modification)
    add_card(modification)
for title_name, title of exportObj.titles
    title.slot = 'Title'
    fixIcons(title)
    add_card(title)
for pilot_name, pilot of exportObj.pilots
    pilot.slot = 'Pilot'
    fixIcons(pilot)
    add_card(pilot)

# Card Lookup
card_lookup_cb = (bot, message) ->
    lookup = strip_name(message.match[1])
    if not card_lookup[lookup]
        return
    text = []
    for card in card_lookup[lookup]
        unique = if card.unique then ':unique:' else ''
        text.push("#{unique}*#{card.slot}* [#{card.points}]")
        if card.limited
            text.push("_Limited._")
        if card.skill  # skill field is (hopefully) unique to pilots
            ship = exportObj.ships[card.ship]
            line = ["#{faction_to_emoji(card.faction)} #{ship_to_icon(card)}#{card.ship}"]

            stats = ":skill#{card.skill}:"
            if ship.attack
                stats += ":attack#{ship.attack}:"
            if ship.energy
                stats += ":energy#{ship.energy}:"
            stats += ":agility#{ship.agility}::hull#{ship.hull}::shield#{ship.shields}:"
            line.push(stats)

            line.push((":#{name_to_emoji(action)}:" for action in ship.actions).join(' '))
            if card.slots.length > 0
                slots = (":#{name_to_emoji(slot)}:" for slot in card.slots).join(' ')
                slots = slots.replace(/:bomb:/g, ':xbomb:')
                line.push(slots)
            text.push(line.join(' - '))
        text.push(card.text)
    return bot.reply(message, text.join('\n'))

controller.hears('(.*)', ['direct_message', 'direct_mention'], card_lookup_cb)
# Handle non-@ mentions
controller.hears('^[rR]2-[dD]7: +(.*)$', ['ambient'], card_lookup_cb)
