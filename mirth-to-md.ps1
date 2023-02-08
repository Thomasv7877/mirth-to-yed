$map = get-location

[xml]$mirth = Get-Content $map\in\*Backup.xml
$groups = @()
$groupsAndChannels = @()
$channels = @()
$md = ""
$counter = 0

$groups += [PSCustomObject]@{
    grIndex = $counter++
    grName = "Default Group"
}

ForEach ($channelgroup in $mirth.serverConfiguration.channelGroups.channelGroup) {
    $groups += [PSCustomObject]@{
        grIndex = $counter
        grName = $channelgroup.name 
    }
    foreach ($channel in $channelgroup.channels.channel){
        $groupsAndChannels += [PSCustomObject]@{
            grIndex = $counter
            chId = $channel.id
        }
    }
    $counter++
}

ForEach ($channel in $mirth.serverConfiguration.channels.channel) {
    $channels += [PSCustomObject]@{
        chID = $channel.id
        chName = $channel.name
        chDesc = $channel.description
    }
}

for ($i = 0 ; $i -le $groups.Length ; $i++){ 
    $md += "# " + $groups[$i].grName + "`n"
    foreach ($channel in $channels){
        $tmpIndex = $groupsAndChannels.chId.IndexOf($channel.chID)
        #$tmpIndex
        #$groupsAndChannels[$tmpIndex].grIndex
        if(($groupsAndChannels[$tmpIndex].grIndex -eq $i) -or ($tmpIndex -eq -1 -and $i -eq 0)){
            $md += "### " + $channel.chName + "`n"
            $md += $channel.chDesc + "`n"
        }
    }
}
#$channels
#$groupsAndChannels
#$groups

$md | Out-File "$map\out\mirth-markdown.md"