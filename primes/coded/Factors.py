# primes count factors

from collections import defaultdict


def count_factors(integer):
    count = defaultdict(int)
    current_divisor = 2
    while current_divisor <= integer:
        while integer % current_divisor == 0:
            integer //= current_divisor
            count[current_divisor] += 1
        current_divisor += 1
    return count


print("4:", count_factors(4))
print("8:", count_factors(8))
print("12:", count_factors(12))

number = 4444488889
print(number, ":", count_factors(number))

"""
4: defaultdict(<class 'int'>, {2: 2})
8: defaultdict(<class 'int'>, {2: 3})
12: defaultdict(<class 'int'>, {2: 2, 3: 1})
4444488889 : defaultdict(<class 'int'>, {163: 2, 409: 2})
"""
