$map = get-location

# xml's used: channel to generate yed giag from, 'blank' xgml and a template xgml where the base nodes are pulled from, after which they get adapted with new info, put in the blank and output as a new file
[xml]$mirth = Get-Content $map\in\*Backup.xml
[xml]$yed = Get-Content "$map\yed_template.xgml"
[xml]$blank = Get-Content "$map\yed_template_blank.xgml"

$counter = 0 # counter needed because every xgml node needs it's own unique id
$groups = @()

$node1 = $blank.ImportNode($yed.section.section.section[1], $true)

# Add default channel to xgml
$node1 = $blank.ImportNode($yed.section.section.section[0], $true)
$node1.attribute[0].InnerText = $counter
$node1.attribute[1].InnerText = "Default Group"
$node1.section[1].attribute[0].InnerText = "Default Group"
$blank.section.section.AppendChild($node1) | Out-Null
$counter++

# loop through channel groups and add to xgml
ForEach ($channelgroup in $mirth.serverConfiguration.channelGroups.channelGroup) {

    $groups += New-Object System.Collections.ArrayList

    $node1 = $blank.ImportNode($yed.section.section.section[0], $true)
    $node1.attribute[0].InnerText = $counter
    $node1.attribute[1].InnerText = $channelgroup.name
    $node1.section[1].attribute[0].InnerText = $channelgroup.name
    $blank.section.section.AppendChild($node1) | Out-Null

    # populate channel group array later used for assignment of group id to channel node in xgml
    foreach ($channel in $channelgroup.channels.channel){
        
        $groups += [PSCustomObject]@{
            grIndex = $counter
            chId = $channel.id
        }

        }
    $counter++
}

# arrays for source and destination connectors, later if folder matches between them an edge between nodes will be generated and inserted in the xgml
$src = @()
$dest1 = @()

# loop through channels, add node to xgml
ForEach ($channel in $mirth.serverConfiguration.channels.channel) {

    # Create channel node
    $node1 = $blank.ImportNode($yed.section.section.section[1], $true)

    $node1.attribute[0].InnerText = ($counter).ToString()
    $node1.attribute[1].InnerText = $channel.name
    $node1.section[1].attribute[0].InnerText = $channel.name
    $gray = "#c0c0c0"
        if($channel.exportData.metadata.enabled -eq "false"){
            $node1.section[0].attribute[4].InnerText = $gray
        }
    # find group id to asign to channel
    $tempIndex = $groups.chId.IndexOf($channel.id)
    $groupId = $groups[$tempIndex].grIndex
    if($tempIndex -eq -1){
        $groupId = 0
    }
    $node1.attribute[2].InnerText = $groupId

    $blank.section.section.AppendChild($node1) | Out-Null
    
    # add source connector to array
    $tmpSrcFolder = $channel.sourceConnector.properties.host
    switch ($channel.sourceConnector.transportName) {
        "Channel Reader" { $tmpSrcFolder = $channel.id }
        "HTTP Listener" { $tmpSrcFolder = $channel.sourceConnector.properties.listenerConnectorProperties.host + ":" + $channel.sourceConnector.properties.listenerConnectorProperties.port }
        "TCP Listener" { $tmpSrcFolder = $channel.sourceConnector.properties.listenerConnectorProperties.host + ":" + $channel.sourceConnector.properties.listenerConnectorProperties.port }
        "database reader" { $tmpSrcFolder = $channel.sourceConnector.properties.url }
    }
    $src += [PSCustomObject]@{
        srcId = $counter
        srcName = $channel.sourceConnector.name
        srcFolder = $tmpSrcFolder
        srcType = $channel.sourceConnector.transportName
    }
    
    # if source connector has move operation, add an entry to the destination array
    if($channel.sourceConnector.properties.afterProcessingAction -eq "MOVE"){
        $dest1 += [PSCustomObject]@{
            destId = $counter
            destName = "MoveAfterProcessing"
            destFolder = $channel.sourceConnector.properties.moveToDirectory
            destType = "File Writer"
        }
    }
    # loop through channel destinations and add entries to array
    foreach ($dest in $channel.destinationConnectors.connector){

        $tmpDestFolder = $dest.properties.host
        switch ($dest.transportName) {
            "SMTP Sender" { $tmpDestFolder = $dest.properties.to }
            "Channel Writer" { $tmpDestFolder = $dest.properties.channelId }
            "TCP Sender" { $tmpDestFolder = $dest.properties.remoteAddress + ":" + $dest.properties.remotePort }
        }
        $dest1 += [PSCustomObject]@{
            destId = $counter
            destName = $dest.name
            destFolder = $tmpDestFolder
            destType = $dest.transportName
            destEnabled = $dest.enabled
        }
    }
    $counter++
} # end of looping through channels

# loop through source and destination arrays, if match with destination make edge, otherwise make source node and edge
for ($i = 0 ; $i -le $src.Length ; $i++){ 
    $match = $false
    for ($y = 0 ; $y -le $dest1.Length ; $y++){
        if($src[$i].srcFolder -eq $dest1[$y].destFolder -and $src[$i].srcFolder -ne $null){
            $match = $true
            # make edge and insert into xgml
            $node1 = $blank.ImportNode($yed.section.section.section[4], $true)
            $node1.attribute[0].InnerText = $dest1[$y].destId
            $node1.attribute[1].InnerText =  $src[$i].srcId
            $node1.attribute[2].InnerText = $src[$i].srcFolder
            $node1.section[1].attribute[0].InnerText = ("({0}) `n{1}" -f $dest1[$y].destName, $src[$i].srcFolder)
            $node1.section[2].attribute[0].InnerText = ""# edge start and end labels blank because of bad positioning in yed
            $node1.section[3].attribute[0].InnerText = ""
            # make edge dashed if mirth destination disabled
            if($dest1[$y].destEnabled -eq "false"){
                $node1.section[0].attribute[0].InnerText = "dashed"
            }
            $blank.section.section.AppendChild($node1) | Out-Null
        }
    }
    # make edge and src node
    if(!$match){
        # non file read/write connectors have dirrefent colors
        $color = "#000000"
        switch($src[$i].srcType){
            "JavaScript Reader" {$color = "#ff9900";break}
            "Channel Reader" {$color = "#3366ff";break}
            "TCP Listener" {$color = "#ff0000";break}
            "HTTP Listener" {$color = "#ff0000";break}
        }
        # generate source node and add to xgml
        $node1 = $blank.ImportNode($yed.section.section.section[2], $true)
        $node1.attribute[0].InnerText = $counter
        if($color -ne "#000000"){
            $node1.section[0].attribute[4].InnerText = $color
            $node1.section[0].attribute[5].InnerText = $color
        }
        $blank.section.section.AppendChild($node1) | Out-Null
        # generate edge, link between previous source node and correct channel node
        $node1 = $blank.ImportNode($yed.section.section.section[4], $true)
            $node1.attribute[0].InnerText = $counter
            $node1.attribute[1].InnerText = $src[$i].srcId
            $node1.attribute[2].InnerText = $src[$i].srcFolder
            if($color -ne "#000000"){
                $node1.section[0].attribute[1].InnerText = $color
            }
            $node1.section[1].attribute[0].InnerText = ("{0} `n{1}" -f "", $src[$i].srcFolder)
            $node1.section[2].attribute[0].InnerText = ""# edge start and end labels blank because of bad positioning in yed
            $node1.section[3].attribute[0].InnerText = ""
            $blank.section.section.AppendChild($node1) | Out-Null
            
        $counter++
    }
}
# loop destinations, if no match with source make destination node and edge (redundant operation)
for ($i = 0 ; $i -le $dest1.Length ; $i++){ 
    $match = $false
    for ($y = 0 ; $y -le $src.Length ; $y++){
        if($src[$y].srcFolder -eq $dest1[$i].destFolder -and $dest1[$i].destFolder -ne $null){
            $match = $true
        }
    }
    if(!$match){
        
        $color = "#000000"
        switch($dest1[$i].destType){
            "JavaScript Writer" {$color = "#ff9900";break}
            "Channel Writer" {$color = "#3366ff";break}
            "TCP Sender" {$color = "#ff0000";break}
            "HTTP Sender" {$color = "#ff0000";break}
        }
        # generate destination node, insert into xgml
        $node1 = $blank.ImportNode($yed.section.section.section[2], $true)
        $node1.attribute[0].InnerText = $counter
        if($color -ne "#000000"){
            $node1.section[0].attribute[4].InnerText = $color
            $node1.section[0].attribute[5].InnerText = $color
        }
        $blank.section.section.AppendChild($node1) | Out-Null
        # generate edge, link between previous destination node and correct channel node
        $node1 = $blank.ImportNode($yed.section.section.section[4], $true)
            $node1.attribute[0].InnerText =  $dest1[$i].destId
            $node1.attribute[1].InnerText = $counter
            $node1.attribute[2].InnerText = $src[$i].destFolder
            if($color -ne "#000000"){
                $node1.section[0].attribute[1].InnerText = $color
            }
            $node1.section[1].attribute[0].InnerText =  $dest1[$i].destFolder
            $node1.section[1].attribute[0].InnerText = ("({0}) `n{1}" -f $dest1[$i].destName, $dest1[$i].destFolder)
            $node1.section[2].attribute[0].InnerText =  ""# edge start and end labels blank because of bad positioning in yed
            $node1.section[3].attribute[0].InnerText = ""
            if($dest1[$i].destEnabled -eq "false"){
                $node1.section[0].attribute[0].InnerText = "dashed"
            }
            $blank.section.section.AppendChild($node1) | Out-Null
            
        $counter++
    }
}

$blank.ChildNodes[0].Encoding = $null
$blank.Save("$map\out\mirth-diagram.xgml")