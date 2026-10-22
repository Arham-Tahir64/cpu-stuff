/* Compile/link check only. This file is not yet executed on a custom CPU. */
volatile unsigned initialized = 7u;
volatile unsigned result;

static unsigned sum(unsigned limit)
{
    unsigned total = 0;
    for (unsigned i = 1; i <= limit; ++i) total += i;
    return total;
}

int main(void)
{
    result = sum(initialized);
    return result == 28u ? 0 : 1;
}
