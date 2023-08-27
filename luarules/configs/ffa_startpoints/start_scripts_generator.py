import os
import shutil

START_SCRIPTS_DIRECTORY = os.path.join(os.path.dirname(__file__), "start_scripts")
PLAYER_NAME = "gg"
CONFIGURATIONS = {
    "Altair_Crossing_V4.1": [4],
    "Carrot Mountains v1.0": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Charlie In The Hills Remake v1.1": [4],
    "Cloud9_V2": [4, 5, 8, 9],
    "Colorado_V2 1.1": [4],
    "Crescent_Bay_V2": [4, 8, 16],
    "Darkside v3.0": [4, 5, 6, 7, 8],
    "DSD 8 Way 1.1": [4, 8, 16],
    "DWorld_V4": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Factions and Factious 0.9": [3, 4, 5, 6, 7, 8, 9, 10],
    "Forge v2.3": [4],
    "Ghenna Rising 4.0": [4, 8, 12],
    "Kolmogorov Remake 3.0": [3, 4, 5, 6, 7, 8, 9, 10],
    "Krakatoa_V2.0": [4, 8, 12, 16],
    "LV412 1.3": [4],
    "Mediterraneum_V1": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Melting Glacier v1.1": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Neurope_Remake 4.2": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Omega Valley V0.1": [4],
    "Oort_Cloud_V2": [3, 4, 6, 8, 12, 16],
    "Red Triangle Remake v1.3": [3, 6, 9],
    "Ring Atoll Remake v2.0": [5, 10],
    "Riverrun_V1": [4, 6, 8],
    "Serene Caldera v1.3": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Sunderance V1.3": [4, 8],
    "The Cold Place BAR v1.1": [3, 6],
    "Throne_V8": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "To Kill The Middle v1.0": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    "Tundra_V2": [4],
    "Valles Marineris 2.6": [4],
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
        # always build a config with no AIs for use with picker
        start_script = gen_start_script(map_name, PLAYER_NAME, 1)
        with open(f"{START_SCRIPTS_DIRECTORY}/{map_name}_Solo.txt", "w") as f:
            f.write(start_script)

        # build from configs
        for nb_teams in configs:
            start_script = gen_start_script(map_name, PLAYER_NAME, nb_teams)
            with open(
                f"{START_SCRIPTS_DIRECTORY}/{map_name}_FFA_{nb_teams}-way.txt", "w"
            ) as f:
                f.write(start_script)
