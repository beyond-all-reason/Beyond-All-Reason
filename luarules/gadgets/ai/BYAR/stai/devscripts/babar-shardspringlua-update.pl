my $babarDir = 'C:\Users\zoggop\Documents\BABAR-The-Shardifant';
my $shardspringluaDir = 'C:\Users\zoggop\Documents\My Games\Spring\games\ShardSpringLua.sdd';
my $BAdir = 'C:\Users\zoggop\Documents\My Games\Spring\games\ba-svn.sdd';
my $BARdir = 'C:\Users\zoggop\Documents\My Games\Spring\games\BAR-svn.sdd';

system "svn update \"$BAdir\"";
system "svn update \"$BARdir\"";

my $babarDesc = `cd $babarDir && git describe --long`;
chomp($babarDesc);
my $shardspringluaDesc = `cd $shardspringluaDir && git describe --long`;
chomp($shardspringluaDesc);
my @babarVer = split('-', $babarDesc);
my @shardspringluaVer = split('-', $shardspringluaDesc);
my $bbVerNum = $babarVer[0];
my $sslVerNum = $shardspringluaVer[0];

print('BABAR-The-Shardifant version: ');
print($bbVerNum);
if ($babarVer[1] > 0) {
	$bbVerNum = $bbVerNum + 1;
	print(' --> ');
	print($bbVerNum);
}
print("\n");

print('ShardSpringLua version: ');
print($sslVerNum);
if ($shardspringluaVer[1] > 0) {
	$sslVerNum = $sslVerNum + 1;
	print(' --> ');
	print($sslVerNum);
}
print("\n");

my $oldVerStr = 'BABAR.*\d+.*ShardSpringLua.*\d+';
my $newVerStr = "BABAR version $bbVerNum -- ShardSpringLua version $sslVerNum";
my @searchFiles;
$searchFiles[0] = "$BAdir\\LuaAI.lua";
$searchFiles[1] = "$BARdir\\LuaAI.lua";

my @curLuaAIVerBABAR;
$curLuaAIVerBABAR[0] = -1;
$curLuaAIVerBABAR[1] = -1;
my @curLuaAIVerShardSpringLua;
$curLuaAIVerShardSpringLua[0] = -1;
$curLuaAIVerShardSpringLua[1] = -1;
for (my $i=0; $i <= 1; $i++) {
	my $file = $searchFiles[$i];
	open(FILE, $file);
	my @lines = <FILE>;
	close(FILE);
	for $line (@lines) {
		if ($line =~ /$oldVerStr/g) {
			chomp($line);
			my @quotes = split("'", $line);
			my @words = split(/\s+/, $quotes[1]);
			my $versionOf;
			for (my $w=0; $w < scalar(@words); $w++) {
				my $word = $words[$w];
				if ($word eq 'BABAR') {
					$versionOf = 'BABAR';
				} elsif ($word eq 'ShardSpringLua') {
					$versionOf = 'ShardSpringLua';
				} elsif ($word =~ /\d+/g) {
					if ($versionOf eq 'BABAR') {
						$curLuaAIVerBABAR[$i] = $word;
					}
					if ($versionOf eq 'ShardSpringLua') {
						$curLuaAIVerShardSpringLua[$i] = $word;
					}
				} elsif (($curLuaAIVerBABAR[$i] != -1) && ($curLuaAIVerShardSpringLua[$i] != -1)) {
					last;
				}
			}
		}
	}
	my $game = "BA";
	if ($i == 1) { $game = "BAR"; }
	print("current $game LuaAI version: BABAR version $curLuaAIVerBABAR[$i], ShardSpringLua version $curLuaAIVerShardSpringLua[$i]\n");
}

if (lc($ARGV[0]) eq 'versioncheck') {
	print("version check only, stopping here.\n");
	exit;
}

if (($curLuaAIVerBABAR[0] != $bbVerNum) || ($curLuaAIVerBABAR[1] != $bbVerNum)) {
	my $stash = `cd \"$babarDir\" && git stash`;
	if ($babarVer[1] > 0) {
		system "cd \"$babarDir\" && git tag -a $bbVerNum -m \"version $bbVerNum\"";
	}
	if ($curLuaAIVerBABAR[0] != $bbVerNum) {
		system "copy /Y \"$babarDir\\*.lua\" \"$BAdir\\luarules\\gadgets\\ai\\BA\\\"";
		system "cd \"$BAdir\\luarules\\gadgets\\ai\\BA\" && erase *table-*.lua";
	}
	if ($curLuaAIVerBABAR[1] != $bbVerNum) {
		system "copy /Y \"$babarDir\\*.lua\" \"$BARdir\\luarules\\gadgets\\ai\\BAR\\\"";
		system "cd \"$BARdir\\luarules\\gadgets\\ai\\BAR\" && erase *table-*.lua";
	}
	chomp($stash);
	if ($stash ne 'No local changes to save') {
		system "cd \"$babarDir\" && git stash apply";	
	}
}

if (($curLuaAIVerShardSpringLua[0] != $sslVerNum) || ($curLuaAIVerShardSpringLua[1] != $sslVerNum)) {
	my $stash = `cd \"$shardspringluaDir\" && git stash`;
	if ($shardspringluaVer[1] > 0) {
		system "cd \"$shardspringluaDir\" && git tag -a $sslVerNum -m \"version $sslVerNum\"";
	}
	if ($curLuaAIVerShardSpringLua[0] != $sslVerNum) {
		system "copy /Y \"$shardspringluaDir\\luarules\\gadgets\\AILoader.lua\" \"$BAdir\\luarules\\gadgets\\AILoader.lua\"";
		system "xcopy /E /Y \"$shardspringluaDir\\luarules\\gadgets\\ai\\*\" \"$BAdir\\luarules\\gadgets\\ai\\\"";
	}
	if ($curLuaAIVerShardSpringLua[1] != $sslVerNum) {
		system "copy /Y \"$shardspringluaDir\\luarules\\gadgets\\AILoader.lua\" \"$BARdir\\luarules\\gadgets\\AILoader.lua\"";
		system "xcopy /E /Y \"$shardspringluaDir\\luarules\\gadgets\\ai\\*\" \"$BARdir\\luarules\\gadgets\\ai\\\"";
	}	
	chomp($stash);
	if ($stash ne 'No local changes to save') {
		system "cd \"$shardspringluaDir\" && git stash apply";	
	}
}

for (my $i=0; $i <= 1; $i++) {
	if (($curLuaAIVerBABAR[$i] != $bbVerNum) || ($curLuaAIVerShardSpringLua[$i] != $sslVerNum))  {
		my $file = $searchFiles[$i];
		open(FILE, $file);
		my @lines = <FILE>;
		close(FILE);
		open(FILE, '>', $file);
		for $line (@lines) {
			$line =~ s/$oldVerStr/$newVerStr/g;
			print FILE $line;
		}
		close(FILE);
		my $gameDir = $BAdir;
		my $game = "BA";
		if ($i == 1) { $gameDir = $BARdir; $game = "BAR"; }
		# system "cd \"$gameDir\" && svn add -q LuaAI.lua luarules\\gadgets\\AILoader.lua luarules\\gadgets\\ai\\* luarules\\gadgets\\ai\\$game\\*";
		system "cd \"$gameDir\" && svn add --force * --auto-props --parents --depth infinity -q";
		system "cd \"$gameDir\" && svn commit -m \"update LuaAI to $newVerStr\"";
	}
}

if ($babarVer[1] > 0) {
	system "cd \"$babarDir\" && git push --tags";
}
if ($shardspringluaVer[1] > 0) {
	system "cd \"$shardspringluaDir\" && git push --tags";
}