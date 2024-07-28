
class Factors
{
    public static Dictionary<long, long> CountFactors(long integer)
    {
        var count = new Dictionary<long, long>();
        long currentDivisor = 2;
        while (currentDivisor <= integer)
        {
            while (integer % currentDivisor == 0)
            {
                integer /= currentDivisor;
                if (count.TryGetValue(currentDivisor, out long value))
                {
                    count[currentDivisor] = value + 1;
                }
                else
                {
                    count[currentDivisor] = 1;
                }
            }
            currentDivisor++;
        }
        return count;
    }

    public static string CountFactorsToString(long integer)
    {
        return string.Join(", ", CountFactors(integer));
    }
}
