<?php
$fh = fopen("last.txt","r");
$last = (int) fread($fh,filesize("last.txt"));
fclose($fh);
$ch = curl_init();
curl_setopt($ch,CURLOPT_URL,"http://search.twitter.com/search.json?q=hackpgh");
curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
$jsonStr =  curl_exec($ch);
curl_close($ch);

$myObj = json_decode($jsonStr,true);

$tweets = array();
$mostRecentId = 0;
foreach($myObj["results"] as $entry){
	$mostRecentId = $mostRecentId > (int) $entry["id"] ? $mostRecentId : (int) $entry["id"];
	array_push($tweets,$entry["id"]."%%".$entry["from_user"]."%%".str_replace("\n",'',$entry["text"]));
}
sort($tweets);
array_reverse($tweets);
//read tweets that havent be rebrodcast
$unusedTweets = "";
if(filesize("tweets.txt") > 0){
	$tweetFH = fopen("tweets.txt","r");
	$unusedTweets = fread($tweetFH,filesize("tweets.txt"));
	fclose($tweetFH);
}
//add new items onto the string
foreach($tweets as $tweetStr){
	$s = explode("%%",$tweetStr);
	if((int)$s[0] > $last){
		$unusedTweets .= $tweetStr."\n";
	}
}
//write new largest id
$fh = fopen("last.txt","w");
fwrite($fh,$mostRecentId);
fclose($fh);
// read off the most recent line off the file
$tweetsArray = explode("\n",$unusedTweets);
echo $tweetsArray[0];
if(count($tweetsArray) > 2){
	$unusedTweets = implode("\n",array_slice($tweetsArray,1));
}
//write unused tweets back to disk
$tweetFH = fopen("tweets.txt","w");
fwrite($tweetFH,$unusedTweets);
fclose($tweetFH);
?>