<?php
	function echoln($str) {
		echo $str;
		echo "\n";
	}

	function usage($reason) {
		echoln("Usage: php build-nix.php [flags]");
		echoln("Flags in parantheses are optional");
		echoln("");
		echoln("  --bits=[32,64]");
		echoln(" (--compiler=[*gcc,clang,icc])        which compiler to use, gcc is default");
		echoln(" (--with-sse2)                        additionally fuzz against SSE2");
		echoln(" (--out=filename)");
		echoln("");
		if ($reason)
			echoln($reason);
	}

	function cleanup() {
		system("rm -f *.o");
	}

	function runcmd($desc, $cmd) {
		echoln($desc);

		$ret = 0;
		system($cmd, $ret);
		if ($ret) {
			cleanup();
			exit;
		}
	}

	class argument {
		var $set, $value;
	}

	class anyargument extends argument {
		function anyargument($flag) {
			global $argc, $argv;

			$this->set = false;

			for ($i = 1; $i < $argc; $i++) {
				if (!preg_match("!--".$flag."=(.*)!", $argv[$i], $m))
					continue;
				$this->value = $m[1];
				$this->set = true;
				return;
			}
		}
	}

	class multiargument extends anyargument {
		function multiargument($flag, $legal_values) {
			parent::anyargument($flag);

			if (!$this->set)
				return;

			$map = array();
			foreach($legal_values as $value)
				$map[$value] = true;

			if (!isset($map[$this->value])) {
				usage("{$this->value} is not a valid parameter to --{$flag}!");
				exit(1);
			}
		}
	}

	class flag extends argument {
		function flag($flag) {
			global $argc, $argv;

			$this->set = false;

			$flag = "--{$flag}";
			for ($i = 1; $i < $argc; $i++) {
				if ($argv[$i] !== $flag)
					continue;
				$this->value = true;
				$this->set = true;
				return;
			}
		}
	}

	$bits = new multiargument("bits", array("32", "64"));
	$compiler = new multiargument("compiler", array("gcc", "clang", "icc"));
	$with_sse2 = new flag("with-sse2");
	$out = new anyargument("out");

	$err = "";
	if (!$bits->set)
		$err .= "--bits not set\n";

	if ($err !== "") {
		usage($err);
		exit;
	}

	$compile = ($compiler->set) ? $compiler->value : "gcc";
	$filename = ($out->set) ? $out->value : "fuzz-curve25519";
	$link = "";
	$flags = "-O3 -m{$bits->value}";
	$ret = 0;
	

	runcmd("building ref10..", "{$compile} {$flags} curve25519-ref10.c -c -o curve25519-ref10.o");
	runcmd("building curve25519..", "{$compile} {$flags} curve25519-donna.c -c -o curve25519-donna.o");
	if ($with_sse2->set) {
		runcmd("building curve25519-sse2..", "{$compile} {$flags} curve25519-donna-sse2.c -c -o curve25519-donna-sse2.o -msse2");
		$link .= " curve25519-donna-sse2.o -DCURVE25519_SSE2";
	}
	runcmd("linking..", "{$compile} {$flags} {$link} fuzz-curve25519.c curve25519-donna.o curve25519-ref10.o -o {$filename}");
	echoln("{$filename} built.");


	cleanup();
?>
