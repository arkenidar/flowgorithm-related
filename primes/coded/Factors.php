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