<?php if( isset($_REQUEST["show-source"]) ) {
    header('Content-Type: text/plain');
    die( file_get_contents( $_SERVER['SCRIPT_FILENAME'] ) );
} ?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>/php/Factors.php</title>
</head>
<body>

<pre>

<?php

function decompo($n)
{
    $assoc = [];
    $divisor = 2;
    while ($divisor <= $n) {
        while ($n % $divisor == 0) {
            $n /= $divisor;
            $next = (int)@$assoc[$divisor] + 1;
            $assoc[$divisor] = $next;
        }
        $divisor++;
    }
    return $assoc;
}

print("\n primes decomposition (tests) \n");

function test($n)
{
    print("\n testing $n : \n\n");
    print_r(decompo($n));
}
test(4);
test(8);
test(12);
test(4444488889);

?>

</pre>
<p><a href="?show-source"> ?show-source </a></p>
<p><a href="."> current folder (php) </a></p>

</body>
</html>
