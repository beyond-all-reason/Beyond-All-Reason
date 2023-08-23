import os
import shutil

START_SCRIPTS_DIRECTORY = os.path.join(os.path.dirname(__file__), "start_scripts")
PLAYER_NAME = "gg"
CONFIGURATIONS = {
    "Carrot Mountains v1.0": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
}


def gen_allyteam(id):
    return f"""
    [allyteam{id}]
    {{
        numallies=0;
    }}"""


def gen_team(id, allyteam_id):
    return f"""
    [team{id}]
    {{
        teamleader=0;
        allyteam={allyteam_id};
    }}"""


def gen_ai(id, team_id):
    return f"""
    [ai{id}]
    {{
        shortname=NullAI;
        name=NullAI;
        version=0.1;
        host=0;
        team={team_id};
    }}"""


def gen_player(name, team_id):
    return f"""
    [player0]
    {{
        name={name};
        team={team_id};
    }}"""


def gen_start_script(map_name, player_name, nb_teams):
    # add player on team 0
    player_team_id = 0
    allyteams = gen_allyteam(player_team_id)
    teams = gen_team(player_team_id, player_team_id)
    player = gen_player(player_name, player_team_id)
    ais = ""
    if nb_teams > 1:
        # add AIs on subsequent teams
        for ai_id in range(1, nb_teams):
            allyteams += gen_allyteam(ai_id)
            teams += gen_team(ai_id, ai_id)
            ais += gen_ai(ai_id, ai_id)

    return f"""[game]
{{
{allyteams}
{teams}
{ais}
{player}
    [modoptions]
    {{
    }}
    mapname={map_name};
    myplayername={player_name};
    ishost=1;
    gametype=Beyond All Reason $VERSION;
    nohelperais=0;
    startPosType=1;
}}"""


if __name__ == "__main__":
    shutil.rmtree(START_SCRIPTS_DIRECTORY, ignore_errors=True)
    os.makedirs(START_SCRIPTS_DIRECTORY)
    for map_name, configs in CONFIGURATIONS.items():
        # build from configs
        for nb_teams in configs:
            start_script = gen_start_script(map_name, PLAYER_NAME, nb_teams)
            with open(
                f"{START_SCRIPTS_DIRECTORY}/{map_name}_FFA_{nb_teams}-way.txt", "w"
            ) as f:
                f.write(start_script)
