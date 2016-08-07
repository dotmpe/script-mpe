#include <regex.h>
#include <stdio.h>

//char parts

int show(void)
{
  printf("matchbox\n");
  FILE *fh = fopen("table.vars", "rt");
  char line[80];
  while (fgets(line, 80, fr) != NULL)
  {
    //sscanf(line, "%ld", &elapsed_seconds);
    //printf("%ld\n", elapsed_seconds);
  }
  fclose(fh);
  return 0;
}

int test(int argc, char *argv[])
{
  int r;
  regex_t reg;

  if ((r = regcomp(&reg, "[A-Z]\\w*", REG_NOSUB | REG_EXTENDED)))
  {
    char errbuf[1024];

    regerror(r, &reg, errbuf, sizeof(errbuf));
    printf("error: %s\n", errbuf);

    return 1;
  }

  for (int i = 0; i < argc; i++)
  {
    if (regexec(&reg, argv[i], 0, NULL, 0) == REG_NOMATCH)
      continue;

    printf("matched: %s\n", argv[i]);
  }
  return 0;
}

int main(int argc, char *argv[])
{
  return show();
}
