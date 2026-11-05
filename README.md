![Team_logo](Aurora_Borealis_ocean.svg)


# AuroraBorealis SCTB

This repository contains the codebase for the team in Student Construction and Technology Bureau in LNTU.


## Prerequisites

Make sure you have the following installed:

- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/)
- [Python](https://www.python.org/) 3.14+ and [Poetry](https://python-poetry.org/)
- [BetterComments](https://marketplace.visualstudio.com/items?itemName=aaron-bond.better-comments) (recomended)


## Run locally

Clone the project

```bash
  git clone https://github.com/Selector0073/AuroraBorealis-SCTB-V2
```

Go to the project directory

```bash
  cd AuroraBorealis-SCTB-V2
```

Create a `.env` file and fill it with the structure `.env.example`

Start the server

```bash
  make api-run
```
**OR**
```bash
  make site-run
```

Run `make help` to see all available commands.


## Run docs locally

Install the docs dependencies (once)

```bash
  cd docs && poetry install && cd ..
```

To run docs live server use

```bash
  make docs-run
```

The docs will be available at <http://127.0.0.1:8000>.

**OR**

To build docs use

```bash
  make docs-build
```


## Running tests

To run tests, run the following command

```bash
  make api-test
```
**OR**
```bash
  make site-test
```


## Documentation

The documentation is written in Markdown, lives in the `docs/` directory and is published automatically after changes are merged into `main`.

The docs home page describes the team workflow in detail.


## Contributing

Direct commits to `main` are **not allowed**. All changes go through a pull request:

1. Create a branch from an up-to-date `main`

    ```bash
      git checkout main
      git pull
      git checkout -b feature-X
    ```

2. Commit your changes to this branch only
3. Push the branch and open a pull request into `main`
4. Get approval, then merge

See the docs home page for the full rules.


## Links

[Docs](https://aurora-borealis-sctb.netlify.app/)

[KanbanFlow](https://kanbanflow.com/board/Lz7yheS)

