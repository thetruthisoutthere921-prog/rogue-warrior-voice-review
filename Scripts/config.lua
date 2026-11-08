return {
 enabled=true,
 volume=0.85, -- 0..1; Windows default playback device, separate from game volume
 gap=0.35,
 reply_delay=0.35,
 reply_distance_m=40,
 mission_delay=3,
 debug=false,
 cooldown={combat=18,enemydown=5,grenadeout=3,missionstart=0,playerreload=6,playerwounded=8,replytoenemy=12,weaponjam=5},
 chance={combat=0.55,enemydown=0.85,grenadeout=1,missionstart=1,playerreload=1,playerwounded=1,replytoenemy=0.8,weaponjam=1},
 -- Exact combat categories, compared after removing punctuation/spaces.
 -- Idle, suspicious activity, finding bodies, hit grunts and death are excluded.
 reply_categories={enemyspotted=true,engagingenemy=true,reloading=true,takingcover=true,covering=true,support=true,requestsupport=true,underfire=true,grenadespotted=true,grenadethrow=true,grenadeout=true,medicrequest=true,requestmedicsupport=true},
}
