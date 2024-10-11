import Time "mo:base/Time";
import Principal "mo:base/Principal";
import TypesICRC7 "/icrc7/types";

module Types {

  public type PlayerId = Principal;
  public type Username = Text;
  public type AvatarID = Nat;
  public type Description = Text;
  public type RegistrationDate = Time.Time;
  public type Level = Nat;
  public type MatchID = Nat;
  public type TokenID = Nat;
  public type Title = Text;

  public type MatchResult = Text;
  public type MatchMap = Text;
  public type PlayerFaction = Text;

  public type UserID = Principal;

  ///////////////////////////////////////
  //Missing  the types for each setting
  public type Settings = {
    #ai;
    #account;
    #audio;
    #video;
    #controls;
    #gameplay;
    #notifications;
  };
  ///////////////////////////////////////

  public type UserProfile = {
    aiFeatures : ?AIFeatures;
    basicInfo : UserBasicInfo;
    referrals : ?ReferralInfo;
    stats : ?PlayerGamesStats;
  };

  public type UserBasicInfo = {
    id : Principal;
    username : Text;
    avatarId : Nat;
    level : Level;
    elo : Float;
    verificationBadge : Bool;
    title : ?Text;
    description : ?Text;
    country : ?Text;
    registrationDate : RegistrationDate;
  };

  public type UserNetwork = {
    connections : [SocialConnection];
    notifications : ?[Notification];
    friends : ?[FriendDetails];
    friendRequests : ?[FriendRequest];
    blockedUsers : ?[UserID];
    following : ?[UserID];
    followers : ?[UserID];
    posts : ?[Post];
  };

  public type SocialConnection = {
    platform : Platform;
    username : Text;
    profileLink : Text;
    memberSince : RegistrationDate;
  };
   public type Platform = {
    #Twitter;
    #WhatsApp;
    #Discord;
    #Facebook;
    #Instagram;
    #DSCVR;
    #Cosmicrafts;
  };

  public type FriendDetails = {
    id : UserID;
    username : Text;
    avatar : Nat;
    friendProfile : ?UserProfile;
  };

  public type FriendRequest = Principal;

  public type MutualFriendship = {
    friend1 : UserID;
    friend2 : UserID;
    friendsSince : Int;
  };

  public type Policy = {
    #acceptAll_interaction : ProfilePrivacy;
    #blockAll_interaction : ProfilePrivacy;
    #friendsOfFriends_interaction : ProfilePrivacy;
    #restrict_profileLookUp : AIFeaturesPrivacy;
    #allow_profileLookUp : AIFeaturesPrivacy;
  };

  public type ProfilePrivacy = {
    interaction : Policy;
  };
  public type AIFeaturesPrivacy = {
    profileLookUp : Policy;
  };
  public type PrivacySettings = {
    profile : ProfilePrivacy;
    aifeatures : AIFeaturesPrivacy;
  };

  public type Notification = {
    id : Nat;
    from : NotificationIdentity;
    timestamp : Time.Time;
    body : Text;
  };

  public type WouID = Text;
  public type MarketingID = Text;
  public type UpdateID = Text;
  
  public type NotificationIdentity = {
    #FriendRequest : UserID;
    #WorldOfUnreal : WouID;
    #Marketing : MarketingID;
    #Update : UpdateID;
  };

 

  public type AIFeatures = {
    aiAvatar : Nat;
    aiBackground : ?Nat;
  };

  public type Post = {
    id : Nat;
    userId : UserID;
    username : Text;
    images : ?[Nat];
    content : Text;
    timestamp : Time.Time;
    likes : ?[Like];
    comments : ?[Comment];
  };

  public type Comment = {
    id : Nat;
    postId : Nat;
    fromUserID : UserID;
    fromUsername : Text;
    content : Text;
    likes : ?[Like];
    timestamp : Time.Time;
  };

  public type Like = {
    id : Nat;
    fromUserID : UserID;
    likeVariant : LikeVariant;
    timestamp : Time.Time;
  };

  public type LikeVariant = {
    #Post;
    #Comment;
  };

  public type UpdateTimestamps = {
    avatar : Nat64;
    description : Nat64;
    username : Nat64;
  };

  //Referals

  public type ReferralCode = Nat;

  public type ReferralInfo = {
    directReferrals : Nat;
    indirectReferrals : Nat;
    multiplier : Float;
  };

  //--
  // Statistics
  public type PlayerStats = {
    playerId : PlayerId;
    energyUsed : Nat;
    energyGenerated : Nat;
    energyWasted : Nat;
    energyChargeRate : Nat;
    xpEarned : Nat;
    damageDealt : Nat;
    damageTaken : Nat;
    damageCritic : Nat;
    damageEvaded : Nat;
    kills : Nat;
    deploys : Nat;
    secRemaining : Nat;
    wonGame : Bool;
    faction : Nat;
    characterID : Nat;
    gameMode : Nat;
    botMode : Nat;
    botDifficulty : Nat;
  };

  public type BasicStats = {
    playerStats : [PlayerStats];
  };

  public type PlayerGamesStats = {
    gamesPlayed : Nat;
    gamesWon : Nat;
    gamesLost : Nat;
    energyGenerated : Nat;
    energyUsed : Nat;
    energyWasted : Nat;
    totalKills : Nat;
    totalDamageDealt : Nat;
    totalDamageTaken : Nat;
    totalDamageCrit : Nat;
    totalDamageEvaded : Nat;
    totalXpEarned : Nat;
    totalGamesWithFaction : [GamesWithFaction];
    totalGamesGameMode : [GamesWithGameMode];
    totalGamesWithCharacter : [GamesWithCharacter];
  };

  public type GamesWithFaction = {
    factionID : Nat;
    gamesPlayed : Nat;
    gamesWon : Nat;
  };

  public type GamesWithGameMode = {
    gameModeID : Nat;
    gamesPlayed : Nat;
    gamesWon : Nat;
  };

  public type GamesWithCharacter = {
    characterID : Nat;
    gamesPlayed : Nat;
    gamesWon : Nat;
  };

  public type AverageStats = {
    averageEnergyGenerated : Nat;
    averageEnergyUsed : Nat;
    averageEnergyWasted : Nat;
    averageDamageDealt : Nat;
    averageKills : Nat;
    averageXpEarned : Nat;
  };

  public type OverallStats = {
    totalGamesPlayed : Nat;
    totalGamesSP : Nat;
    totalGamesMP : Nat;
    totalDamageDealt : Nat;
    totalTimePlayed : Nat;
    totalKills : Nat;
    totalEnergyGenerated : Nat;
    totalEnergyUsed : Nat;
    totalEnergyWasted : Nat;
    totalXpEarned : Nat;
    totalGamesWithFaction : [OverallGamesWithFaction];
    totalGamesGameMode : [OverallGamesWithGameMode];
    totalGamesWithCharacter : [OverallGamesWithCharacter];
  };

  public type OverallGamesWithFaction = {
    factionID : Nat;
    gamesPlayed : Nat;
  };

  public type OverallGamesWithGameMode = {
    gameModeID : Nat;
    gamesPlayed : Nat;
  };

  public type OverallGamesWithCharacter = {
    characterID : Nat;
    gamesPlayed : Nat;
  };
  //--
  // Matchmaking
  public type MMInfo = {
    id : PlayerId;
    matchAccepted : Bool;
    elo : Float;
    playerGameData : PlayerGameData;
    lastPlayerActive : Nat64;
    username : Username;
  };

  public type MMStatus = {
    #Searching;
    #Reserved;
    #Accepting;
    #Accepted;
    #InGame;
    #Ended;
  };

  public type MMSearchStatus = {
    #Assigned;
    #Available;
    #NotAvailable;
  };

  public type MMPlayerStatus = {
    status : MMStatus;
    matchID : MatchID;
  };

  public type MatchData = {
    matchID : MatchID;
    player1 : MMInfo;
    player2 : ?MMInfo;
    status : MMStatus;
  };

  public type FullMatchData = {
    matchID : MatchID;
    player1 : {
      id : PlayerId;
      username : Username;
      avatar : AvatarID;
      level : Level;
      matchAccepted : Bool;
      elo : Float;
      playerGameData : PlayerGameData;
    };
    player2 : ?{
      id : PlayerId;
      username : Username;
      avatar : AvatarID;
      level : Level;
      matchAccepted : Bool;
      elo : Float;
      playerGameData : PlayerGameData;
    };
    status : MMStatus;
  };
  //--
  // Match History
  public type MatchOpt = {
    #Ranked;
    #Normal;
    #Tournament;
  };

  public type PlayerRecord = {
    playerId : Principal;
    faction : PlayerFaction;
  };

  public type MatchRecord = {
    matchID : MatchID;
    map : MatchMap;
    team1 : [PlayerRecord];
    team2 : [PlayerRecord];
    faction1 : [PlayerFaction];
    faction2 : [PlayerFaction];
    result : MatchResult;
    timestamp : Time.Time;
    mode : MatchOpt;
  };

  public type PlayerGameData = {
    deck : [Nat]; // Array of token IDs
    // Add other relevant fields here if necessary
  };
  //--
  // Missions
  public type MissionType = {
    #GamesCompleted;
    #GamesWon;
    #DamageDealt;
    #DamageTaken;
    #EnergyUsed;
    #UnitsDeployed;
    #FactionPlayed;
    #GameModePlayed;
    #XPEarned;
    #Kills;
  };

  public type MissionRewardType = {
    #Chest;
    #Stardust;
    // #NFTXP;
  };

  public type MissionOption = {
    MissionType : MissionType;
    minAmount : Nat;
    maxAmount : Nat;
    rarity : Nat;
  };

  public type Mission = {
    id : Nat;
    missionCategory : MissionCategory;
    missionType : MissionType;
    name : Text;
    reward_type : MissionRewardType;
    reward_amount : Nat;
    start_date : Nat64;
    end_date : Nat64;
    total : Nat;
  };

  public type MissionCategory = {
    #Weekly;
    #Daily;
    #Hourly;
    #Free;
    #Achievement;
  };

  public type MissionsUser = {
    id_mission : Nat;
    missionCategory : MissionCategory;
    total : Nat;
    progress : Nat;
    finished : Bool;
    finish_date : Nat64;
    start_date : Nat64;
    expiration : Nat64;
    missionType : MissionType;
    reward_type : MissionRewardType;
    reward_amount : Nat;
  };

  public type MissionProgress = {
    missionType : MissionType;
    progress : Nat;
  };

  public type MissionTemplate = {
    name : Text;
    missionCategory : MissionCategory;
    missionType : MissionType;
    rewardType : MissionRewardType;
    minReward : Nat;
    maxReward : Nat;
    total : Nat;
    hoursActive : Nat64;
  };

  public type RewardPool = {
    chestRarity : (Nat, Nat);
    stardust : (Nat, Nat);
  };

  //--
  //Achievements

  public type AchievementCategory = {
    id : Nat;
    name : Text;
    achievements : [AchievementLine];
    reward : [AchievementReward];
    requiredProgress : Nat;
    completed : Bool;
    progress : Nat;
    claimed : Bool;
  };

  public type AchievementLine = {
    id : Nat;
    name : Text;
    individualAchievements : [IndividualAchievement];
    categoryId : Nat;
    reward : [AchievementReward];
    requiredProgress : Nat;
    completed : Bool;
    progress : Nat;
    claimed : Bool;
  };

  public type IndividualAchievement = {
    id : Nat;
    achievementId : Nat;
    name : Text;
    achievementType : AchievementType;
    requiredProgress : Nat;
    completed : Bool;
    reward : [AchievementReward];
    progress : Nat;
    claimed : Bool;
  };

  public type AchievementReward = {
    rewardType : AchievementRewardsType;
    amount : Nat;
  };

  public type AchievementRewardsType = {
    #Stardust;
    #Chest;
    #Title;
    #Avatar;
    #NFT;
    #XP;
    #Multiplier;
  };

  public type NFTDetails = {
    unitType : TypesICRC7.Unit;
    name : Text;
    description : Text;
    image : Text;
    faction : TypesICRC7.Faction;
    rarity : Nat;
    level : Nat;
    health : Nat;
    damage : Nat;
    combatExperience : Nat;
  };

  public type AchievementType = {
    #AchievementsUnlocked;
    #ChestsMinted;
    #ChestsOpened;
    #Customization;
    #DailyMissionsCompleted;
    #DamageDealt;
    #DamageTaken;
    #EnergyUsed;
    #FluxMinted;
    #FriendsAdded;
    #GameModePlayed;
    #GamesCompleted;
    #GamesPlayed;
    #GamesWithCharacter;
    #GamesWithFaction;
    #GamesWon;
    #Kills;
    #LevelReached;
    #NFTsMinted;
    #RewardsClaimed;
    #ShardsMinted;
    #Social;
    #TimePlayed;
    #UnitsDeployed;
    #UpgradeNFT;
    #UserMissionsCompleted;
    #WeeklyMissionsCompleted;
    #XPEarned;
  };

};
