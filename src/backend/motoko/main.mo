import PseudoRandomX "mo:xtended-random/PseudoRandomX";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Random "mo:base/Random";
import Nat8 "mo:base/Nat8";
import Timer "mo:base/Timer";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Trie "mo:base/Trie";
import Types "Types";
import Utils "Utils";
import ICRC7Utils "/icrc7/utils";
import TypesICRC7 "/icrc7/types";
import TypesICRC1 "/icrc1/Types";
import Int64 "mo:base/Int64";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import ICRC1 "/icrc1/canisters/..";
import MetadataUtils "MetadataUtils";
import Validator "Validator";
import MissionOptions "MissionOptions";
import AchievementData "AchievementData";
import Set "Set";

shared actor class Cosmicrafts() = Self {

  //#region |Types|

  public type UserID = Types.UserID;
  public type Result<T, E> = { #ok : T; #err : E };
  public type PlayerId = Types.PlayerId;
  public type Username = Types.Username;
  public type AvatarID = Types.AvatarID;
  public type Description = Types.Description;
  public type RegistrationDate = Types.RegistrationDate;
  public type Level = Types.Level;

  public type MutualFriendship = Types.MutualFriendship;
  public type UpdateTimestamps = Types.UpdateTimestamps;

  public type GamesWithFaction = Types.GamesWithFaction;
  public type GamesWithGameMode = Types.GamesWithGameMode;
  public type GamesWithCharacter = Types.GamesWithCharacter;
  public type BasicStats = Types.BasicStats;
  public type PlayerStats = Types.PlayerStats;
  public type PlayerGamesStats = Types.PlayerGamesStats;
  public type OverallStats = Types.OverallStats;
  public type AverageStats = Types.AverageStats;
  public type OverallGamesWithFaction = Types.OverallGamesWithFaction;
  public type OverallGamesWithGameMode = Types.OverallGamesWithGameMode;
  public type OverallGamesWithCharacter = Types.OverallGamesWithCharacter;

  public type MMInfo = Types.MMInfo;
  public type MMSearchStatus = Types.MMSearchStatus;
  public type MMStatus = Types.MMStatus;
  public type MMPlayerStatus = Types.MMPlayerStatus;
  public type MatchData = Types.MatchData;
  public type FullMatchData = Types.FullMatchData;
  public type MatchID = Types.MatchID;
  public type PlayerGameData = Types.PlayerGameData;

  public type MissionType = Types.MissionType;
  public type MissionCategory = Types.MissionCategory;
  public type RewardType = Types.MissionRewardType;
  public type Mission = Types.Mission;
  public type MissionsUser = Types.MissionsUser;
  public type MissionProgress = Types.MissionProgress;
  public type MissionTemplate = Types.MissionTemplate;
  public type RewardPool = Types.RewardPool;
  public type MissionOption = Types.MissionOption;
  public type TokenId = TypesICRC7.TokenId;

  public type AchievementCategory = Types.AchievementCategory;
  public type AchievementLine = Types.AchievementLine;
  public type IndividualAchievement = Types.IndividualAchievement;
  public type AchievementReward = Types.AchievementReward;
  public type AchievementRewardsType = Types.AchievementRewardsType;
  public type NFTDetails = Types.NFTDetails;
  public type AchievementType = Types.AchievementType;

  //Timer
  public type Duration = Timer.Duration;
  public type TimerId = Timer.TimerId;

  //ICRC
  public type TokenID = Types.TokenID;

  //#endregion

  //#region |Admin Functions|

  public type AdminFunction = {
    #CreateMission : (Text, MissionCategory, MissionType, RewardType, Nat, Nat, Nat64);
    #CreateMissionsPeriodically : ();
    #MintChest : (Principal, Nat);
    #BurnToken : (?TypesICRC7.Account, TypesICRC7.Account, TypesICRC7.TokenId, Nat64);
    #GetCollectionOwner : TypesICRC7.Account;
    #GetInitArgs : TypesICRC7.CollectionInitArgs;
  };

  public shared func admin(funcToCall : AdminFunction) : async (Bool, Text) {
    Debug.print("Admin function called by admin.");
    switch (funcToCall) {
      case (#CreateMission(name, missionCategory, missionType, rewardType, rewardAmount, total, hours_active)) {
        let (success, message, id) = await createGeneralMission(name, missionCategory, missionType, rewardType, rewardAmount, total, hours_active);
        return (success, message # " Mission ID: " # Nat.toText(id));
      };
      case (#CreateMissionsPeriodically()) {
        await createMissionsPeriodically();
        return (true, "Missions created.");
      };
      case (#MintChest(PlayerId, rarity)) {
        let (success, message) = await mintChest(PlayerId, rarity);
        return (success, message);
      };
      case (#BurnToken(_caller, from, tokenId, now)) {
        let result = await _burnToken(_caller, from, tokenId, now);
        switch (result) {
          case null return (true, "Token burned successfully.");
          case (?error) return (false, "Failed to burn token: " # Utils.transferErrorToText(error));
        };
      };
      case (#GetCollectionOwner(_)) {
        return (true, "Collection Owner: " # debug_show (icrc7_CollectionOwner));
      };
      case (#GetInitArgs(_)) {
        return (true, "Init Args: " # debug_show (icrc7_InitArgs));
      };
    };
  };
  // #endregion

  // #region |Admin tools|

  // migrations BEFORE deployment

  // Nulls or Anons cannot use matchmaking (later add non registered players and Level req. + loss default inactivity)
  let NULL_PRINCIPAL : Principal = Principal.fromText("aaaaa-aa");
  let ANON_PRINCIPAL : Principal = Principal.fromText("2vxsx-fae");

  let ADMIN_PRINCIPAL = Principal.fromText("vam5o-bdiga-izgux-6cjaz-53tck-eezzo-fezki-t2sh6-xefok-dkdx7-pae");

  //mainnet
  //let canister_ID = Principal.fromText("opcce-byaaa-aaaak-qcgda-cai");

  //local
  let canister_ID = Principal.fromText("bkyz2-fmaaa-aaaaa-qaaaq-cai");

  public type InitArgs = TypesICRC1.InitArgs;


  // #endregion

  // #region |Missions|

  let ONE_HOUR : Nat64 = 60 * 60 * 1_000_000_000;
  let ONE_DAY : Nat64 = 60 * 60 * 24 * 1_000_000_000;
  let ONE_WEEK : Nat64 = 60 * 60 * 24 * 7 * 1_000_000_000; // 60 secs * 60 minutes * 24 hours * 7

  var lastDailyMissionCreationTime : Nat64 = 0;
  var lastWeeklyMissionCreationTime : Nat64 = 0;
  stable var lastDailyFreeRewardMissionCreationTime : Nat64 = 0;

  stable var shuffledDailyIndices : [Nat] = [];
  stable var currentDailyIndex : Nat = 0;

  stable var shuffledHourlyIndices : [Nat] = [];
  stable var currentHourlyIndex : Nat = 0;

  stable var shuffledWeeklyIndices : [Nat] = [];
  stable var currentWeeklyIndex : Nat = 0;

  stable var shuffledDailyFreeRewardIndices : [Nat] = [];
  stable var currentDailyFreeRewardIndex : Nat = 0;

  func initializeShuffledHourlyMissions() : async () {
    let indices : [Nat] = Array.tabulate(MissionOptions.hourlyMissions.size(), func(i : Nat) : Nat { i });
    shuffledHourlyIndices := Utils.shuffleArray(indices);
    currentHourlyIndex := 0;
  };

  func initializeShuffledDailyMissions() : async () {
    let indices : [Nat] = Array.tabulate(MissionOptions.dailyMissions.size(), func(i : Nat) : Nat { i });
    shuffledDailyIndices := Utils.shuffleArray(indices);
    currentDailyIndex := 0;
  };

  func initializeShuffledWeeklyMissions() : async () {
    let indices : [Nat] = Array.tabulate(MissionOptions.weeklyMissions.size(), func(i : Nat) : Nat { i });
    shuffledWeeklyIndices := Utils.shuffleArray(indices);
    currentWeeklyIndex := 0;
  };

  func initializeShuffledDailyFreeRewardMissions() : async () {
    let indices : [Nat] = Array.tabulate(MissionOptions.dailyFreeReward.size(), func(i : Nat) : Nat { i });
    shuffledDailyFreeRewardIndices := Utils.shuffleArray(indices);
    currentDailyFreeRewardIndex := 0;
  };

  func createDailyMissions() : async [(Bool, Text, Nat)] {
    var resultBuffer = Buffer.Buffer<(Bool, Text, Nat)>(0);

    // Check if the list needs to be shuffled
    if (shuffledDailyIndices.size() == 0 or currentDailyIndex >= shuffledDailyIndices.size()) {
      await initializeShuffledDailyMissions();
    };

    // Select the next mission from the shuffled list
    let index = shuffledDailyIndices[currentDailyIndex];
    let template = MissionOptions.dailyMissions[index];
    let result = await createSingleConcurrentMission(template);
    resultBuffer.add(result);

    // Move to the next index
    currentDailyIndex += 1;

    return Buffer.toArray(resultBuffer);
  };

  func createWeeklyMissions() : async [(Bool, Text, Nat)] {
    var resultBuffer = Buffer.Buffer<(Bool, Text, Nat)>(0);

    // Check if the list needs to be shuffled
    if (shuffledWeeklyIndices.size() == 0 or currentWeeklyIndex >= shuffledWeeklyIndices.size()) {
      await initializeShuffledWeeklyMissions();
    };

    // Select the next mission from the shuffled list
    let index = shuffledWeeklyIndices[currentWeeklyIndex];
    let template = MissionOptions.weeklyMissions[index];
    let result = await createSingleConcurrentMission(template);
    resultBuffer.add(result);

    // Move to the next index
    currentWeeklyIndex += 1;

    return Buffer.toArray(resultBuffer);
  };

  func createDailyFreeRewardMissions() : async [(Bool, Text, Nat)] {
    var resultBuffer = Buffer.Buffer<(Bool, Text, Nat)>(0);

    // Check if the list needs to be shuffled
    if (shuffledDailyFreeRewardIndices.size() == 0 or currentDailyFreeRewardIndex >= shuffledDailyFreeRewardIndices.size()) {
      await initializeShuffledDailyFreeRewardMissions();
    };

    // Select the next mission from the shuffled list
    let index = shuffledDailyFreeRewardIndices[currentDailyFreeRewardIndex];
    let template = MissionOptions.dailyFreeReward[index];
    let result = await createSingleConcurrentMission(template);
    resultBuffer.add(result);

    // Move to the next index
    currentDailyFreeRewardIndex += 1;

    return Buffer.toArray(resultBuffer);
  };

  func createSingleConcurrentMission(template : Types.MissionTemplate) : async (Bool, Text, Nat) {
    let rewardAmount = Utils.getMaxMin(template.minReward, template.maxReward);
    return await createGeneralMission(
      template.name,
      template.missionCategory,
      template.missionType,
      template.rewardType,
      rewardAmount,
      template.total,
      template.hoursActive,
    );
  };

  public func createMissionsPeriodically() : async () {
    let now = Nat64.fromIntWrap(Time.now());
    Debug.print("[createMissionsPeriodically] Current time: " # Nat64.toText(now));

    // Create and start all tasks concurrently
    let dailyTask = async {
      if (now - lastDailyMissionCreationTime >= ONE_DAY) {
        let dailyResults = await createDailyMissions();
        await Utils.logMissionResults(dailyResults, "Daily");
        lastDailyMissionCreationTime := now;
      };
    };

    let weeklyTask = async {
      if (now - lastWeeklyMissionCreationTime >= ONE_WEEK) {
        let weeklyResults = await createWeeklyMissions();
        await Utils.logMissionResults(weeklyResults, "Weekly");
        lastWeeklyMissionCreationTime := now;
      };
    };

    let dailyFreeRewardTask = async {
      if (now - lastDailyFreeRewardMissionCreationTime >= ONE_HOUR * 4) {
        let dailyFreeResults = await createDailyFreeRewardMissions();
        await Utils.logMissionResults(dailyFreeResults, "Daily Free Reward");
        lastDailyFreeRewardMissionCreationTime := now;
      };
    };

    // Await all tasks concurrently
    let dailyTaskFuture = dailyTask;
    let weeklyTaskFuture = weeklyTask;
    let dailyFreeRewardTaskFuture = dailyFreeRewardTask;

    await dailyTaskFuture;
    await weeklyTaskFuture;
    await dailyFreeRewardTaskFuture;

    // Set the timer to call this function again after 1 hour
    let _ : Timer.TimerId = Timer.setTimer<system>(
      #seconds(60 * 60),
      func() : async () {
        await createMissionsPeriodically();
      },
    );
  };
  // #endregion

  // #region |General Missions|

  //Stable Vars
  stable var generalMissionIDCounter : Nat = 1;
  stable var _generalUserProgress : [(Principal, [MissionsUser])] = [];
  stable var _missions : [(Nat, Mission)] = [];
  stable var _activeMissions : [(Nat, Mission)] = [];
  stable var _claimedRewards : [(Principal, [Nat])] = [];
  stable var _generalMissionIDCounter : Nat = 1;

  // HashMaps for General Missions
  var missions : HashMap.HashMap<Nat, Mission> = HashMap.fromIter(_missions.vals(), 0, Utils._natEqual, Utils._natHash);
  var activeMissions : HashMap.HashMap<Nat, Mission> = HashMap.fromIter(_activeMissions.vals(), 0, Utils._natEqual, Utils._natHash);
  var claimedRewards : HashMap.HashMap<Principal, [Nat]> = HashMap.fromIter(_claimedRewards.vals(), 0, Principal.equal, Principal.hash);
  var generalUserProgress : HashMap.HashMap<Principal, [MissionsUser]> = HashMap.fromIter(_generalUserProgress.vals(), 0, Principal.equal, Principal.hash);

  // Function to create a new general mission
  func createGeneralMission(name : Text, missionCategory : MissionCategory, missionType : MissionType, rewardType : RewardType, rewardAmount : Nat, total : Nat, hoursActive : Nat64) : async (Bool, Text, Nat) {
    let id = generalMissionIDCounter;
    generalMissionIDCounter += 1;

    let now = Nat64.fromIntWrap(Time.now());
    let duration = ONE_HOUR * hoursActive;
    let endDate = now + duration;

    let newMission : Mission = {
      id = id;
      name = name;
      missionCategory = missionCategory;
      missionType = missionType;
      reward_type = rewardType;
      reward_amount = rewardAmount;
      start_date = now;
      end_date = endDate;
      total = total;
    };

    missions.put(id, newMission);
    activeMissions.put(id, newMission);
    Debug.print("[createGeneralMission] Mission created with ID: " # Nat.toText(id) # ", End Date: " # Nat64.toText(endDate) # ", Start Date: " # Nat64.toText(now));

    return (true, "Mission created successfully", id);
  };

  // Function to update progress for general missions
  func updateGeneralMissionProgress(user : Principal, missionsProgress : [MissionProgress]) : async (Bool, Text) {
    //Debug.print("[updateGeneralMissionProgress] Updating general mission progress for user: " # Principal.toText(user));
    //Debug.print("[updateGeneralMissionProgress] Missions progress: " # debug_show(missionsProgress));

    var userMissions : [MissionsUser] = switch (generalUserProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    //Debug.print("[updateGeneralMissionProgress] User's current missions: " # debug_show(userMissions));

    let now : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    let updatedMissions = Buffer.Buffer<MissionsUser>(userMissions.size());

    for (mission in userMissions.vals()) {
      //Debug.print("[updateGeneralMissionProgress] Processing mission: " # debug_show(mission));
      if (mission.finished) {
        updatedMissions.add(mission);
      } else {
        var updatedMission = mission;
        for (progress in missionsProgress.vals()) {
          if (mission.missionType == progress.missionType) {
            let updatedProgress = mission.progress + progress.progress;
            //Debug.print("[updateGeneralMissionProgress] Updated progress for missionType " # debug_show(mission.missionType) # ": " # debug_show(updatedProgress));
            if (updatedProgress >= mission.total) {
              updatedMission := {
                mission with
                progress = updatedProgress;
                finished = true;
                finish_date = now;
              };
            } else {
              updatedMission := {
                mission with
                progress = updatedProgress;
              };
            };
          };
        };
        updatedMissions.add(updatedMission);
      };
    };

    generalUserProgress.put(user, Buffer.toArray(updatedMissions));
    //Debug.print("[updateGeneralMissionProgress] Updated user missions: " # debug_show(generalUserProgress.get(user)));
    return (true, "Progress added successfully to general missions");
  };

  // Function to assign new general missions to a user
  func assignGeneralMissions(user : Principal) : async () {

    var userMissions : [MissionsUser] = switch (generalUserProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    var claimedRewardsForUser : [Nat] = switch (claimedRewards.get(user)) {
      case (null) { [] };
      case (?claimed) { claimed };
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));
    let buffer = Buffer.Buffer<MissionsUser>(0);

    // Remove expired or claimed missions
    for (mission in userMissions.vals()) {
      if (mission.expiration >= now and not Utils.arrayContains<Nat>(claimedRewardsForUser, mission.id_mission, Utils._natEqual)) {
        buffer.add(mission);
      };
    };

    // Collect IDs of current missions to avoid duplication
    let currentMissionIds = Buffer.Buffer<Nat>(buffer.size());
    for (mission in buffer.vals()) {
      currentMissionIds.add(mission.id_mission);
    };

    // Add new active missions to the user
    for ((id, mission) in activeMissions.entries()) {
      if (not Utils.arrayContains<Nat>(Buffer.toArray(currentMissionIds), id, Utils._natEqual) and not Utils.arrayContains<Nat>(claimedRewardsForUser, id, Utils._natEqual)) {
        let isDailyFreeReward = checkIfDailyFreeRewardMission(mission); // Check if the mission is a daily free reward mission
        buffer.add({
          id_mission = id;
          missionCategory = mission.missionCategory;
          reward_amount = mission.reward_amount;
          start_date = mission.start_date;
          progress = 0; // Initialize with 0 progress
          finish_date = 0; // Initialize finish date to 0
          expiration = mission.end_date;
          missionType = mission.missionType;
          finished = isDailyFreeReward; // Set finished based on mission type
          reward_type = mission.reward_type;
          total = mission.total;
        });
      };
    };

    // Update user missions
    generalUserProgress.put(user, Buffer.toArray(buffer));
  };

  // Helper function to check if a mission is a daily free reward mission
  func checkIfDailyFreeRewardMission(mission : Mission) : Bool {
    for (template in MissionOptions.dailyFreeReward.vals()) {
      if (mission.name == template.name and mission.missionType == template.missionType and mission.reward_type == template.rewardType) {
        return true;
      };
    };
    return false;
  };

  // Function to get general missions for a user
  public shared ({ caller }) func getGeneralMissions() : async [MissionsUser] {
    // Step 1: Assign new general missions to the user
    await assignGeneralMissions(caller);

    // Step 2: Search for active general missions assigned to the user
    let activeMissions : [MissionsUser] = await searchActiveGeneralMissions(caller);

    // Directly return the active missions with updated progress
    return activeMissions;
  };

  // Function to search for active general missions for a user
  public query func searchActiveGeneralMissions(user : Principal) : async [MissionsUser] {
    let now : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    var userMissions : [MissionsUser] = switch (generalUserProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    var claimedRewardsForUser : [Nat] = switch (claimedRewards.get(user)) {
      case (null) { [] };
      case (?claimed) { claimed };
    };

    let activeMissions = Buffer.Buffer<MissionsUser>(0);
    for (mission in userMissions.vals()) {
      if (mission.expiration >= now and not Utils.arrayContains<Nat>(claimedRewardsForUser, mission.id_mission, Utils._natEqual)) {
        activeMissions.add(mission);
      };
    };

    return Buffer.toArray(activeMissions);
  };

  // Function to get the progress of a specific general mission for a user
  public query func getGeneralMissionProgress(user : Principal, missionID : Nat) : async ?MissionsUser {
    let userMissions : [MissionsUser] = switch (generalUserProgress.get(user)) {
      case (null) return null;
      case (?missions) missions;
    };

    for (mission in userMissions.vals()) {
      if (mission.id_mission == missionID) {
        return ?mission;
      };
    };
    return null;
  };

  public shared (msg) func claimGeneralReward(idMission : Nat) : async (Bool, Text) {
    let missionOpt = await getGeneralMissionProgress(msg.caller, idMission);
    switch (missionOpt) {
      case (null) {
        return (false, "Mission not assigned");
      };
      case (?mission) {
        let currentTime : Nat64 = Nat64.fromNat(Int.abs(Time.now()));

        // Check if the mission has expired
        if (currentTime > mission.expiration) {
          return (false, "Mission has expired");
        };

        // Check if the mission reward has already been claimed
        let claimedRewardsForUser = switch (claimedRewards.get(msg.caller)) {
          case (null) { [] };
          case (?rewards) { rewards };
        };
        if (Array.find<Nat>(claimedRewardsForUser, func(r) { r == idMission }) != null) {
          return (false, "Mission reward has already been claimed");
        };

        // Check if the mission is finished
        if (not mission.finished) {
          return (false, "Mission not finished");
        };

        // Check if the finish date is valid (should be before or equal to expiration date)
        if (mission.finish_date > mission.expiration) {
          return (false, "Mission finish date is after the expiration date");
        };

        // If all checks pass, mint the rewards
        let (success, rewardMessage) = await mintGeneralRewards(mission, msg.caller);
        if (success) {
          // Determine XP range based on the mission category
          let (minXp, maxXp) = MissionOptions.getXpRange(mission.missionCategory);
          // Generate XP reward
          let xpReward = Utils.getMaxMin(minXp, maxXp);

          // Ensure player stats are initialized
          var playerStatsOpt = playerGamesStats.get(msg.caller);
          if (playerStatsOpt == null) {
            // Initialize player stats without capturing the return value
            ignore await _initializeNewPlayerStats(msg.caller);
            playerStatsOpt := playerGamesStats.get(msg.caller);
          };

          // Update player's total XP
          switch (playerStatsOpt) {
            case (null) {}; // This should not happen, but included for safety
            case (?stats) {
              var updatedStats = {
                stats with totalXpEarned = stats.totalXpEarned + xpReward
              };
              playerGamesStats.put(msg.caller, updatedStats);
            };
          };

          // Update player's level based on new total XP
          let (_, _) = await updatePlayerLevel(msg.caller);

          // Remove claimed reward from userProgress and add it to claimedRewards
          var userMissions : [MissionsUser] = switch (generalUserProgress.get(msg.caller)) {
            case (null) { [] };
            case (?missions) { missions };
          };
          let updatedMissions = Buffer.Buffer<MissionsUser>(userMissions.size());
          for (r in userMissions.vals()) {
            if (r.id_mission != idMission) {
              updatedMissions.add(r);
            };
          };
          generalUserProgress.put(msg.caller, Buffer.toArray(updatedMissions));

          // Add claimed reward to claimedRewards
          let updatedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewardsForUser.size() + 1);
          for (reward in claimedRewardsForUser.vals()) {
            updatedRewardsBuffer.add(reward);
          };
          updatedRewardsBuffer.add(idMission);
          claimedRewards.put(msg.caller, Buffer.toArray(updatedRewardsBuffer));

          // Return success message with XP gained and reward details
          return (true, "Mission reward claimed successfully. " # rewardMessage # ". XP gained: " # Nat.toText(xpReward));
        };
        return (success, rewardMessage);
      };
    };
  };

  func mintGeneralRewards(mission : MissionsUser, caller : Principal) : async (Bool, Text) {
    var claimHistory = switch (claimedRewards.get(caller)) {
      case (null) { [] };
      case (?history) { history };
    };

    if (Utils.arrayContains(claimHistory, mission.id_mission, Utils._natEqual)) {
      return (false, "Mission already claimed");
    };

    switch (mission.reward_type) {
      case (#Chest) {
        let (success, message) = await mintChest(caller, mission.reward_amount);
        if (success) {
          let updatedClaimHistoryBuffer = Buffer.Buffer<Nat>(claimHistory.size() + 1);
          for (reward in claimHistory.vals()) {
            updatedClaimHistoryBuffer.add(reward);
          };
          updatedClaimHistoryBuffer.add(mission.id_mission);
          claimedRewards.put(caller, Buffer.toArray(updatedClaimHistoryBuffer));
        };
        return (success, message);
      };
      case (#Stardust) {
        let mintArgs : ICRC1.Mint = {
          to = { owner = caller; subaccount = null };
          amount = mission.reward_amount;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };
        let mintResult = await mint(mintArgs);
        switch (mintResult) {
          case (#Ok(_transactionID)) {
            await updateMintedStardust(caller, mission.reward_amount);
            let updatedClaimHistoryBuffer = Buffer.Buffer<Nat>(claimHistory.size() + 1);
            for (reward in claimHistory.vals()) {
              updatedClaimHistoryBuffer.add(reward);
            };
            updatedClaimHistoryBuffer.add(mission.id_mission);
            claimedRewards.put(caller, Buffer.toArray(updatedClaimHistoryBuffer));
            return (true, "Stardust minted and reward claimed. Quantity: " # Nat.toText(mission.reward_amount));
          };
          case (#Err(_error)) {
            return (false, "Minting stardust failed");
          };
        };
      };
    };
  };
  // #endregion

  // #region |User-Specific Missions|

  //Stable Variables
  stable var _userMissionProgress : [(Principal, [MissionsUser])] = [];
  stable var _userMissions : [(Principal, [Mission])] = [];
  stable var _userMissionCounters : [(Principal, Nat)] = [];
  stable var _userClaimedRewards : [(Principal, [Nat])] = [];

  // HashMaps for User-Specific Missions
  var userMissionProgress : HashMap.HashMap<Principal, [MissionsUser]> = HashMap.fromIter(_userMissionProgress.vals(), 0, Principal.equal, Principal.hash);
  var userMissions : HashMap.HashMap<Principal, [Mission]> = HashMap.fromIter(_userMissions.vals(), 0, Principal.equal, Principal.hash);
  var userMissionCounters : HashMap.HashMap<Principal, Nat> = HashMap.fromIter(_userMissionCounters.vals(), 0, Principal.equal, Principal.hash);
  var userClaimedRewards : HashMap.HashMap<Principal, [Nat]> = HashMap.fromIter(_userClaimedRewards.vals(), 0, Principal.equal, Principal.hash);

  // Function to create a new user-specific mission
  public func createUserMission(user : PlayerId) : async (Bool, Text, Nat) {
    var userSpecificProgressList : [MissionsUser] = switch (userMissionProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));

    // Check if there are active missions for each category and renew them if necessary
    var hasActiveHourly = false;
    var hasActiveDaily = false;
    var hasActiveWeekly = false;
    var hasActiveFree = true;
    var hasActiveAchievement = true;

    for (mission in userSpecificProgressList.vals()) {
      if (mission.expiration >= now and not mission.finished) {
        switch (mission.missionCategory) {
          case (#Hourly) { hasActiveHourly := true };
          case (#Daily) { hasActiveDaily := true };
          case (#Weekly) { hasActiveWeekly := true };
          case (#Free) { hasActiveFree := true };
          case (#Achievement) { hasActiveAchievement := true };
        };
      };
    };

    // Initialize shuffled indices if necessary
    let initHourlyFuture = if (shuffledHourlyIndices.size() == 0 or currentHourlyIndex >= shuffledHourlyIndices.size()) {
      initializeShuffledHourlyMissions();
    } else {
      async {};
    };

    let initDailyFuture = if (shuffledDailyIndices.size() == 0 or currentDailyIndex >= shuffledDailyIndices.size()) {
      initializeShuffledDailyMissions();
    } else {
      async {};
    };

    let initWeeklyFuture = if (shuffledWeeklyIndices.size() == 0 or currentWeeklyIndex >= shuffledWeeklyIndices.size()) {
      initializeShuffledWeeklyMissions();
    } else {
      async {};
    };

    await initHourlyFuture;
    await initDailyFuture;
    await initWeeklyFuture;

    // Create new missions if there are no active ones in the respective category
    let hourlyResult = if (not hasActiveHourly) {
      let res = await createUserSpecificMission(user, MissionOptions.hourlyMissions, shuffledHourlyIndices, currentHourlyIndex, ONE_HOUR);
      currentHourlyIndex += 1;
      res;
    } else { (true, "Hourly mission is still active.", 0) };

    let _dailyResult = if (not hasActiveDaily) {
      let res = await createUserSpecificMission(user, MissionOptions.dailyMissions, shuffledDailyIndices, currentDailyIndex, ONE_DAY);
      currentDailyIndex += 1;
      res;
    } else { (true, "Daily mission is still active.", 0) };

    let _weeklyResult = if (not hasActiveWeekly) {
      let res = await createUserSpecificMission(user, MissionOptions.weeklyMissions, shuffledWeeklyIndices, currentWeeklyIndex, ONE_WEEK);
      currentWeeklyIndex += 1;
      res;
    } else { (true, "Weekly mission is still active.", 0) };

    await assignUserMissions(user);

    return (true, "User-specific missions checked and renewed if necessary.", hourlyResult.2);
  };

  // Helper function to create a user-specific mission
  func createUserSpecificMission(
    user : PlayerId,
    missionOptions : [Types.MissionTemplate],
    shuffledIndices : [Nat],
    currentIndex : Nat,
    duration : Nat64,
  ) : async (Bool, Text, Nat) {
    let index = shuffledIndices[currentIndex];
    let template = missionOptions[index];
    let rewardAmount = Utils.getMaxMin(template.minReward, template.maxReward);

    var userMissionsList : Buffer.Buffer<Mission> = switch (userMissions.get(user)) {
      case (null) { Buffer.Buffer<Mission>(0) };
      case (?missions) { Buffer.fromArray<Mission>(missions) };
    };

    let missionIDCounter = switch (userMissionCounters.get(user)) {
      case (null) { 0 };
      case (?counter) { counter };
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));
    let newMission : Mission = {
      id = missionIDCounter;
      name = template.name;
      missionCategory = template.missionCategory;
      missionType = template.missionType;
      reward_type = template.rewardType;
      reward_amount = rewardAmount;
      start_date = now;
      end_date = now + duration;
      total = template.total;
      finished = false;
    };

    userMissionCounters.put(user, missionIDCounter + 1);
    userMissionsList.add(newMission);
    userMissions.put(user, Buffer.toArray(userMissionsList));

    return (true, "User-specific mission created.", newMission.id);
  };

  // Function to update progress for user-specific missions
  func updateUserMissionsProgress(
    user : Principal,
    playerStats : {
      secRemaining : Nat;
      energyGenerated : Nat;
      damageDealt : Nat;
      damageTaken : Nat;
      energyUsed : Nat;
      deploys : Nat;
      faction : Nat;
      gameMode : Nat;
      xpEarned : Nat;
      kills : Nat;
      wonGame : Bool;
    },
  ) : async (Bool, Text) {

    //Debug.print("[updateUserMissions] Updating user-specific mission progress for user: " # Principal.toText(user));
    //Debug.print("[updateUserMissions] Player stats: " # debug_show(playerStats));

    var userSpecificProgressList = switch (userMissionProgress.get(user)) {
      case (null) { [] };
      case (?progress) { progress };
    };

    //Debug.print("[updateUserMissions] User's current missions: " # debug_show(userSpecificProgressList));

    let now : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    let updatedMissions = Buffer.Buffer<MissionsUser>(userSpecificProgressList.size());

    for (mission in userSpecificProgressList.vals()) {
      //Debug.print("[updateUserMissions] Processing mission: " # debug_show(mission));
      if (mission.finished) {
        updatedMissions.add(mission);
      } else {
        var updatedMission = mission;

        switch (mission.missionType) {
          case (#GamesCompleted) {
            updatedMission := {
              mission with progress = mission.progress + 1
            };
          };
          case (#GamesWon) {
            if (playerStats.secRemaining > 0) {
              updatedMission := {
                mission with progress = mission.progress + 1
              };
            };
          };
          case (#DamageDealt) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.damageDealt
            };
          };
          case (#DamageTaken) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.damageTaken
            };
          };
          case (#EnergyUsed) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.energyUsed
            };
          };
          case (#UnitsDeployed) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.deploys
            };
          };
          case (#FactionPlayed) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.faction
            };
          };
          case (#GameModePlayed) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.gameMode
            };
          };
          case (#XPEarned) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.xpEarned
            };
          };
          case (#Kills) {
            updatedMission := {
              mission with progress = mission.progress + playerStats.kills
            };
          };
        };

        //Debug.print("[updateUserMissions] Updated mission progress: " # debug_show(updatedMission.progress));

        if (updatedMission.progress >= updatedMission.total) {
          updatedMission := {
            updatedMission with
            progress = updatedMission.total;
            finished = true;
            finish_date = now;
          };
        };

        updatedMissions.add(updatedMission);
      };
    };

    userMissionProgress.put(user, Buffer.toArray(updatedMissions));
    //Debug.print("[updateUserMissions] Updated user missions: " # debug_show(userMissionProgress.get(user)));
    return (true, "Progress updated successfully in user-specific missions");
  };

  // Function to assign new user-specific missions to a user
  func assignUserMissions(user : PlayerId) : async () {
    var userSpecificProgressList : [MissionsUser] = switch (userMissionProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    var claimedRewardsForUser : [Nat] = switch (userClaimedRewards.get(user)) {
      case (null) { [] };
      case (?claimed) { claimed };
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));
    let buffer = Buffer.Buffer<MissionsUser>(0);

    // Remove expired or claimed missions
    for (mission in userSpecificProgressList.vals()) {
      if (mission.expiration >= now and not Utils.arrayContains<Nat>(claimedRewardsForUser, mission.id_mission, Utils._natEqual)) {
        buffer.add(mission);
      };
    };

    // Collect IDs of current missions to avoid duplication
    let currentMissionIds = Buffer.Buffer<Nat>(buffer.size());
    for (mission in buffer.vals()) {
      currentMissionIds.add(mission.id_mission);
    };

    // Check if the user has missions and add new active missions to the user
    switch (userMissions.get(user)) {
      case (null) {};
      case (?missions) {
        for (mission in missions.vals()) {
          if (not Utils.arrayContains<Nat>(Buffer.toArray(currentMissionIds), mission.id, Utils._natEqual) and not Utils.arrayContains<Nat>(claimedRewardsForUser, mission.id, Utils._natEqual)) {
            buffer.add({
              id_mission = mission.id;
              missionCategory = mission.missionCategory;
              reward_amount = mission.reward_amount;
              start_date = mission.start_date;
              progress = 0; // Initialize with 0 progress
              finish_date = 0; // Initialize finish date to 0
              expiration = mission.end_date;
              missionType = mission.missionType;
              finished = false;
              reward_type = mission.reward_type;
              total = mission.total;
            });
          };
        };
      };
    };

    userMissionProgress.put(user, Buffer.toArray(buffer));
  };

  public shared ({ caller }) func getUserMissions() : async [MissionsUser] {
    // Step 1: Immediately create a new user-specific mission
    let (_created, _message, _missionId) = await createUserMission(caller);
    //Debug.print("[getUserMissions] createUserMission result: " # debug_show(created) # ", message: " # message);

    // Step 2: Search for active user-specific missions assigned to the user
    var activeMissions : [MissionsUser] = await searchActiveUserMissions(caller);

    return activeMissions;
  };

  // Function to search for active user-specific missions
  public query func searchActiveUserMissions(user : PlayerId) : async [MissionsUser] {
    let now : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    var userMissions = switch (userMissionProgress.get(user)) {
      case (null) { [] };
      case (?missions) { missions };
    };

    var claimedRewardsForUser = switch (userClaimedRewards.get(user)) {
      case (null) { [] };
      case (?claimed) { claimed };
    };

    let activeMissions = Buffer.Buffer<MissionsUser>(0);
    for (mission in userMissions.vals()) {
      if (mission.expiration >= now and not Utils.arrayContains<Nat>(claimedRewardsForUser, mission.id_mission, Utils._natEqual)) {
        activeMissions.add(mission);
      };
    };

    return Buffer.toArray(activeMissions);
  };

  // Function to get the progress of a user-specific mission
  public query func getUserMissionProgress(user : PlayerId, missionID : Nat) : async ?MissionsUser {
    let userMissions = switch (userMissionProgress.get(user)) {
      case (null) return null;
      case (?missions) missions;
    };

    for (mission in userMissions.vals()) {
      if (mission.id_mission == missionID) {
        return ?mission;
      };
    };
    return null;
  };

  public shared (msg) func claimUserReward(idMission : Nat) : async (Bool, Text) {
    let missionOpt = await getUserMissionProgress(msg.caller, idMission);
    switch (missionOpt) {
      case (null) {
        return (false, "Mission not assigned");
      };
      case (?mission) {
        let currentTime : Nat64 = Nat64.fromNat(Int.abs(Time.now()));

        if (currentTime > mission.expiration) {
          return (false, "Mission has expired");
        };

        let claimedRewardsForUser = switch (userClaimedRewards.get(msg.caller)) {
          case (null) { [] };
          case (?rewards) { rewards };
        };
        if (Array.find<Nat>(claimedRewardsForUser, func(r) { r == idMission }) != null) {
          return (false, "Mission reward has already been claimed");
        };

        if (not mission.finished) {
          return (false, "Mission not finished");
        };

        if (mission.finish_date > mission.expiration) {
          return (false, "Mission finish date is after the expiration date");
        };

        let (success, rewardMessage) = await mintUserRewards(mission, msg.caller);
        if (success) {
          let (minXp, maxXp) = MissionOptions.getXpRange(mission.missionCategory);
          let xpReward = Utils.getMaxMin(minXp, maxXp);

          var playerStatsOpt = playerGamesStats.get(msg.caller);
          if (playerStatsOpt == null) {
            ignore await _initializeNewPlayerStats(msg.caller);
            playerStatsOpt := playerGamesStats.get(msg.caller);
          };

          switch (playerStatsOpt) {
            case (null) {};
            case (?stats) {
              var updatedStats = {
                stats with totalXpEarned = stats.totalXpEarned + xpReward
              };
              playerGamesStats.put(msg.caller, updatedStats);
            };
          };

          let (_, _) = await updatePlayerLevel(msg.caller);

          var userMissions = switch (userMissionProgress.get(msg.caller)) {
            case (null) { [] };
            case (?missions) { missions };
          };
          let updatedMissions = Buffer.Buffer<MissionsUser>(userMissions.size());
          for (r in userMissions.vals()) {
            if (r.id_mission != idMission) {
              updatedMissions.add(r);
            };
          };
          userMissionProgress.put(msg.caller, Buffer.toArray(updatedMissions));

          let updatedClaimedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewardsForUser.size() + 1);
          for (reward in claimedRewardsForUser.vals()) {
            updatedClaimedRewardsBuffer.add(reward);
          };
          updatedClaimedRewardsBuffer.add(idMission);
          userClaimedRewards.put(msg.caller, Buffer.toArray(updatedClaimedRewardsBuffer));

          // After claiming the reward, check and renew missions
          ignore await createUserMission(msg.caller);

          return (true, "Mission reward claimed successfully. " # rewardMessage # ". XP gained: " # Nat.toText(xpReward));
        };
        return (success, rewardMessage);
      };
    };
  };

  func mintUserRewards(mission : MissionsUser, caller : Principal) : async (Bool, Text) {
    var claimHistory = switch (userClaimedRewards.get(caller)) {
      case (null) { [] };
      case (?history) { history };
    };

    if (Utils.arrayContains(claimHistory, mission.id_mission, Utils._natEqual)) {
      return (false, "Mission already claimed");
    };

    switch (mission.reward_type) {
      case (#Chest) {
        let (success, message) = await mintChest(caller, mission.reward_amount);
        if (success) {
          let updatedClaimHistoryBuffer = Buffer.Buffer<Nat>(claimHistory.size() + 1);
          for (reward in claimHistory.vals()) {
            updatedClaimHistoryBuffer.add(reward);
          };
          updatedClaimHistoryBuffer.add(mission.id_mission);
          userClaimedRewards.put(caller, Buffer.toArray(updatedClaimHistoryBuffer));
        };
        return (success, message);
      };
      case (#Stardust) {
        let mintArgs : ICRC1.Mint = {
          to = { owner = caller; subaccount = null };
          amount = mission.reward_amount;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };
        let mintResult = await mint(mintArgs);
        switch (mintResult) {
          case (#Ok(_transactionID)) {
            await updateMintedStardust(caller, mission.reward_amount);
            let updatedClaimHistoryBuffer = Buffer.Buffer<Nat>(claimHistory.size() + 1);
            for (reward in claimHistory.vals()) {
              updatedClaimHistoryBuffer.add(reward);
            };
            updatedClaimHistoryBuffer.add(mission.id_mission);
            userClaimedRewards.put(caller, Buffer.toArray(updatedClaimHistoryBuffer));
            return (true, "Stardust minted and reward claimed. Quantity: " # Nat.toText(mission.reward_amount));
          };
          case (#Err(_error)) {
            return (false, "Minting stardust failed");
          };
        };
      };
    };
  };
  // #endregion

  // #region |Progress Manager|

  // Function to update achievement progress manager (cleaned version)
  func updateAchievementProgressManager(
    _user : Principal,
    _playerStats : {
      secRemaining : Nat;
      energyGenerated : Nat;
      damageDealt : Nat;
      damageTaken : Nat;
      energyUsed : Nat;
      deploys : Nat;
      faction : Nat;
      gameMode : Nat;
      xpEarned : Nat;
      kills : Nat;
      wonGame : Bool;
      // Add other criteria like tokens minted, friends added, etc. here
    },
  ) : async (Bool, Text) {

    // Cleaned version - no operations performed

    return (true, "Achievement progress manager update skipped.");
  };

  public func updateProgressManager(user : Principal, playerStats : PlayerStats) : async (Bool, Text) {
    let generalProgressBuffer = Buffer.Buffer<MissionProgress>(9);

    generalProgressBuffer.add({
      missionType = #GamesCompleted;
      progress = 1;
    });
    generalProgressBuffer.add({
      missionType = #DamageDealt;
      progress = playerStats.damageDealt;
    });
    generalProgressBuffer.add({
      missionType = #DamageTaken;
      progress = playerStats.damageTaken;
    });
    generalProgressBuffer.add({
      missionType = #EnergyUsed;
      progress = playerStats.energyUsed;
    });
    generalProgressBuffer.add({
      missionType = #UnitsDeployed;
      progress = playerStats.deploys;
    });

    // Increment progress for the specific faction played
    generalProgressBuffer.add({ missionType = #FactionPlayed; progress = 1 });

    generalProgressBuffer.add({
      missionType = #GameModePlayed;
      progress = playerStats.gameMode;
    });
    generalProgressBuffer.add({
      missionType = #XPEarned;
      progress = playerStats.xpEarned;
    });
    generalProgressBuffer.add({
      missionType = #Kills;
      progress = playerStats.kills;
    });

    if (playerStats.wonGame) {
      generalProgressBuffer.add({ missionType = #GamesWon; progress = 1 });
    };

    let generalProgress = Buffer.toArray(generalProgressBuffer);

    let (result1, message1) = await updateGeneralMissionProgress(user, generalProgress);
    let (result2, message2) = await updateUserMissionsProgress(user, playerStats);
    let (result3, message3) = await updateAchievementProgressManager(user, playerStats);

    let success = result1 and result2 and result3;
    let message = message1 # " | " # message2 # " | " # message3;

    return (success, message);
  };

  //GameStats
  public func updatePlayerGameStats(playerId : PlayerId, _playerStats : PlayerStats, _winner : Nat, _looser : Nat) {
    switch (playerGamesStats.get(playerId)) {
      case (null) {
        let _gs : PlayerGamesStats = {
          gamesPlayed = 1;
          gamesWon = _winner;
          gamesLost = _looser;
          energyGenerated = _playerStats.energyGenerated;
          energyUsed = _playerStats.energyUsed;
          energyWasted = _playerStats.energyWasted;
          totalKills = _playerStats.kills;
          totalDamageDealt = _playerStats.damageDealt;
          totalDamageTaken = _playerStats.damageTaken;
          totalDamageCrit = _playerStats.damageCritic;
          totalDamageEvaded = _playerStats.damageEvaded;
          totalXpEarned = _playerStats.xpEarned;
          totalGamesWithFaction = [{
            factionID = _playerStats.faction;
            gamesPlayed = 1;
            gamesWon = _winner;
          }];
          totalGamesGameMode = [{
            gameModeID = _playerStats.gameMode;
            gamesPlayed = 1;
            gamesWon = _winner;
          }];
          totalGamesWithCharacter = [{
            characterID = _playerStats.characterID;
            gamesPlayed = 1;
            gamesWon = _winner;
          }];
        };
        playerGamesStats.put(playerId, _gs);
      };
      case (?_bs) {
        // Update cumulative stats with simple addition
        let updatedGamesWithFaction = updateGamesWithFaction(_bs.totalGamesWithFaction, _playerStats.faction, _winner);
        let updatedGamesWithGameMode = updateGamesWithGameMode(_bs.totalGamesGameMode, _playerStats.gameMode, _winner);
        let updatedGamesWithCharacter = updateGamesWithCharacter(_bs.totalGamesWithCharacter, _playerStats.characterID, _winner);

        let _gs : PlayerGamesStats = {
          gamesPlayed = _bs.gamesPlayed + 1;
          gamesWon = _bs.gamesWon + _winner;
          gamesLost = _bs.gamesLost + _looser;
          energyGenerated = _bs.energyGenerated + _playerStats.energyGenerated;
          energyUsed = _bs.energyUsed + _playerStats.energyUsed;
          energyWasted = _bs.energyWasted + _playerStats.energyWasted;
          totalKills = _bs.totalKills + _playerStats.kills;
          totalDamageDealt = _bs.totalDamageDealt + _playerStats.damageDealt;
          totalDamageTaken = _bs.totalDamageTaken + _playerStats.damageTaken;
          totalDamageCrit = _bs.totalDamageCrit + _playerStats.damageCritic;
          totalDamageEvaded = _bs.totalDamageEvaded + _playerStats.damageEvaded;
          totalXpEarned = _bs.totalXpEarned + _playerStats.xpEarned;
          totalGamesWithFaction = updatedGamesWithFaction;
          totalGamesGameMode = updatedGamesWithGameMode;
          totalGamesWithCharacter = updatedGamesWithCharacter;
        };
        playerGamesStats.put(playerId, _gs);

        // Trigger level update without waiting
        ignore updatePlayerLevel(playerId);
      };
    };
  };

  private func updateGamesWithFaction(existing : [GamesWithFaction], faction : Nat, winner : Nat) : [GamesWithFaction] {
    var found = false;
    let buffer = Buffer.Buffer<GamesWithFaction>(existing.size());
    for (item in existing.vals()) {
      if (item.factionID == faction) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          factionID = faction;
          gamesWon = item.gamesWon + winner;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({
        gamesPlayed = 1;
        factionID = faction;
        gamesWon = winner;
      });
    };
    return Buffer.toArray(buffer);
  };

  private func updateGamesWithGameMode(existing : [GamesWithGameMode], gameModeID : Nat, winner : Nat) : [GamesWithGameMode] {
    var found = false;
    let buffer = Buffer.Buffer<GamesWithGameMode>(existing.size());
    for (item in existing.vals()) {
      if (item.gameModeID == gameModeID) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          gameModeID = gameModeID;
          gamesWon = item.gamesWon + winner;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({
        gamesPlayed = 1;
        gameModeID = gameModeID;
        gamesWon = winner;
      });
    };
    return Buffer.toArray(buffer);
  };

  private func updateGamesWithCharacter(existing : [GamesWithCharacter], characterID : Nat, winner : Nat) : [GamesWithCharacter] {
    var found = false;
    let buffer = Buffer.Buffer<GamesWithCharacter>(existing.size());
    for (item in existing.vals()) {
      if (item.characterID == characterID) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          characterID = characterID;
          gamesWon = item.gamesWon + winner;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({
        gamesPlayed = 1;
        characterID = characterID;
        gamesWon = winner;
      });
    };
    return Buffer.toArray(buffer);
  };

  //OverallStats
  func updateOverallStats(_matchID : MatchID, _playerStats : PlayerStats) {

    // Update specific game modes, factions, and characters
    let updatedGamesWithFaction = updateOverallGamesWithFaction(overallStats.totalGamesWithFaction, _playerStats.faction);
    let updatedGamesWithGameMode = updateOverallGamesWithGameMode(overallStats.totalGamesGameMode, _playerStats.gameMode);
    let updatedGamesWithCharacter = updateOverallGamesWithCharacter(overallStats.totalGamesWithCharacter, _playerStats.characterID);

    let maxGameTime : Nat = 300; // 5 minutes in seconds
    let timePlayed : Nat = maxGameTime - _playerStats.secRemaining;

    // Construct a new overallStats record with updated values
    overallStats := {
      totalGamesPlayed = overallStats.totalGamesPlayed + 1;
      totalGamesSP = if (_playerStats.gameMode == 2) overallStats.totalGamesSP + 1 else overallStats.totalGamesSP;
      totalGamesMP = if (_playerStats.gameMode == 1) overallStats.totalGamesMP + 1 else overallStats.totalGamesMP;
      totalDamageDealt = overallStats.totalDamageDealt + _playerStats.damageDealt;
      totalTimePlayed = overallStats.totalTimePlayed + timePlayed;
      totalKills = overallStats.totalKills + _playerStats.kills;
      totalEnergyUsed = overallStats.totalEnergyUsed + _playerStats.energyUsed;
      totalEnergyGenerated = overallStats.totalEnergyGenerated + _playerStats.energyGenerated;
      totalEnergyWasted = overallStats.totalEnergyWasted + _playerStats.energyWasted;
      totalGamesWithFaction = updatedGamesWithFaction;
      totalGamesGameMode = updatedGamesWithGameMode;
      totalGamesWithCharacter = updatedGamesWithCharacter;
      totalXpEarned = overallStats.totalXpEarned + _playerStats.xpEarned;
    };
  };

  private func updateOverallGamesWithFaction(existing : [OverallGamesWithFaction], faction : Nat) : [OverallGamesWithFaction] {
    var found = false;
    let buffer = Buffer.Buffer<OverallGamesWithFaction>(existing.size());
    for (item in existing.vals()) {
      if (item.factionID == faction) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          factionID = faction;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({ gamesPlayed = 1; factionID = faction });
    };
    return Buffer.toArray(buffer);
  };

  private func updateOverallGamesWithGameMode(existing : [OverallGamesWithGameMode], gameModeID : Nat) : [OverallGamesWithGameMode] {
    var found = false;
    let buffer = Buffer.Buffer<OverallGamesWithGameMode>(existing.size());
    for (item in existing.vals()) {
      if (item.gameModeID == gameModeID) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          gameModeID = gameModeID;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({ gamesPlayed = 1; gameModeID = gameModeID });
    };
    return Buffer.toArray(buffer);
  };

  private func updateOverallGamesWithCharacter(existing : [OverallGamesWithCharacter], characterID : Nat) : [OverallGamesWithCharacter] {
    var found = false;
    let buffer = Buffer.Buffer<OverallGamesWithCharacter>(existing.size());
    for (item in existing.vals()) {
      if (item.characterID == characterID) {
        buffer.add({
          gamesPlayed = item.gamesPlayed + 1;
          characterID = characterID;
        });
        found := true;
      } else {
        buffer.add(item);
      };
    };
    if (not found) {
      buffer.add({ gamesPlayed = 1; characterID = characterID });
    };
    return Buffer.toArray(buffer);
  };

  // Save Game
  public shared (msg) func saveFinishedGame(
    matchID : MatchID,
    _playerStats : {
      secRemaining : Nat;
      energyGenerated : Nat;
      damageDealt : Nat;
      wonGame : Bool;
      botMode : Nat;
      deploys : Nat;
      damageTaken : Nat;
      damageCritic : Nat;
      damageEvaded : Nat;
      energyChargeRate : Nat;
      faction : Nat;
      energyUsed : Nat;
      gameMode : Nat;
      energyWasted : Nat;
      xpEarned : Nat;
      characterID : Nat;
      botDifficulty : Nat;
      kills : Nat;
    },
  ) : async (Bool, Text) {
    var _txt : Text = "";

    // Creating a local playerStats variable from the input parameter
    var playerStats = {
      secRemaining = _playerStats.secRemaining;
      energyGenerated = _playerStats.energyGenerated;
      damageDealt = _playerStats.damageDealt;
      wonGame = _playerStats.wonGame;
      playerId = msg.caller;
      botMode = _playerStats.botMode;
      deploys = _playerStats.deploys;
      damageTaken = _playerStats.damageTaken;
      damageCritic = _playerStats.damageCritic;
      damageEvaded = _playerStats.damageEvaded;
      energyChargeRate = _playerStats.energyChargeRate;
      faction = _playerStats.faction;
      energyUsed = _playerStats.energyUsed;
      gameMode = _playerStats.gameMode;
      energyWasted = _playerStats.energyWasted;
      xpEarned = 0; // Initial XP set to 0, will be calculated below
      characterID = _playerStats.characterID;
      botDifficulty = _playerStats.botDifficulty;
      kills = _playerStats.kills;
    };

    Debug.print("[saveFinishedGame] Player stats: " # debug_show (playerStats));

    let isExistingMatch = switch (basicStats.get(matchID)) {
      case (null) { false };
      case (?_) { true };
    };

    let endingGame : (Bool, Bool, ?Principal) = await setGameOver(msg.caller);
    let isPartOfMatch = await isCallerPartOfMatch(matchID, msg.caller);
    if (not isPartOfMatch) {
      return (false, "You are not part of this match.");
    };

    if (isExistingMatch) {
      switch (basicStats.get(matchID)) {
        case (null) {
          return (false, "Unexpected error: Match not found");
        };
        case (?_bs) {
          for (ps in _bs.playerStats.vals()) {
            if (ps.playerId == msg.caller) {
              return (false, "You have already submitted stats for this match.");
            };
          };
        };
      };
    };

    // Determine the XP to be awarded based on win or loss
    let awardedXP : Nat = if (playerStats.wonGame) {
      // Winning grants 100-125 XP
      Utils.getMaxMin(100, 125);
    } else {
      // Losing grants 50-75 XP
      Utils.getMaxMin(50, 75);
    };

    // Update the xpEarned field in playerStats
    playerStats := { playerStats with xpEarned = awardedXP };

    // Retrieve the player's current deck from the Trie
    let playerDeckOpt = Trie.get(playerDecks, _keyFromPrincipal(msg.caller), Principal.equal);
    let playerDeck = switch (playerDeckOpt) {
      case (null) {
        return (false, "Error: No deck found for the player.");
      };
      case (?data) {
        data.deck;
      };
    };

    // Update games played in the soul metadata
    ignore await updateSoulNFTPlayed(playerDeck);

    // Call handleCombatXP with the retrieved deck, total XP, and the player's Principal
    let updatedUnits = await handleCombatXP(playerDeck, playerStats.xpEarned);
    Debug.print("Updated units after combat XP handling: " # debug_show (updatedUnits));

    if (not isExistingMatch) {
      let newBasicStats : BasicStats = {
        playerStats = [playerStats];
      };
      basicStats.put(matchID, newBasicStats);

      let (_gameValid, validationMsg) = Validator.validateGame(300 - playerStats.secRemaining, playerStats.xpEarned);
      if (not _gameValid) {
        onValidation.put(matchID, newBasicStats);
        return (false, validationMsg);
      };

      let _winner = if (playerStats.wonGame) 1 else 0;
      let _looser = if (not playerStats.wonGame) 1 else 0;
      let _elo : Bool = await updatePlayerELO(msg.caller, _winner, endingGame.2);

      let (success, message) = await updateProgressManager(msg.caller, playerStats);

      if (not success) {
        return (false, "Failed to update progress: " # message);
      };

      // Update PlayerGamesStats cumulatively with accurate stats
      updatePlayerGameStats(msg.caller, playerStats, _winner, _looser);

      // Update OverallStats cumulatively with accurate stats
      updateOverallStats(matchID, playerStats);

      return (true, "Game saved: " # message);
    } else {
      switch (basicStats.get(matchID)) {
        case (null) {
          return (false, "Unexpected error: Match not found");
        };
        case (?_bs) {
          let updatedPlayerStatsBuffer = Buffer.Buffer<PlayerStats>(_bs.playerStats.size() + 1);
          for (ps in _bs.playerStats.vals()) {
            updatedPlayerStatsBuffer.add(ps);
          };
          updatedPlayerStatsBuffer.add(playerStats);
          let updatedPlayerStats = Buffer.toArray(updatedPlayerStatsBuffer);
          let updatedBasicStats : BasicStats = {
            playerStats = updatedPlayerStats;
          };
          basicStats.put(matchID, updatedBasicStats);

          let (_gameValid, validationMsg) = Validator.validateGame(300 - playerStats.secRemaining, playerStats.xpEarned);
          if (not _gameValid) {
            onValidation.put(matchID, updatedBasicStats);
            return (false, validationMsg);
          };

          let _winner = if (playerStats.wonGame) 1 else 0;
          let _looser = if (not playerStats.wonGame) 1 else 0;
          let _elo : Bool = await updatePlayerELO(msg.caller, _winner, endingGame.2);

          let (success, message) = await updateProgressManager(msg.caller, playerStats);

          if (not success) {
            return (false, "Failed to update progress: " # message);
          };

          // Update PlayerGamesStats cumulatively with accurate stats
          updatePlayerGameStats(msg.caller, playerStats, _winner, _looser);

          // Update OverallStats cumulatively with accurate stats
          updateOverallStats(matchID, playerStats);

          return (true, _txt # " - Game saved: " # message);
        };
      };
    };
  };

  public func updatePlayerLevel(playerId : Principal) : async (Bool, Text) {
    let playerOpt = userBasicInfo.get(playerId);
    switch (playerOpt) {
      case (?player) {
        let totalXp = switch (playerGamesStats.get(playerId)) {
          case (null) 0;
          case (?stats) stats.totalXpEarned;
        };
        let updatedPlayer : UserBasicInfo = {
          id = player.id;
          username = player.username;
          avatarId = player.avatarId;
          level = Utils.calculateLevel(totalXp);
          elo = 1200.0;
          verificationBadge = false;
          title = null;
          description = null;
          country = null;
          registrationDate = player.registrationDate;
        };
        userBasicInfo.put(playerId, updatedPlayer);
        return (true, "Player level updated successfully");
      };
      case (null) { (false, "Player not found") };
    };
  };
  // #endregion

  // #region |Users|

  public type UserBasicInfo = Types.UserBasicInfo;
  public type UserNameBasicInfo = Text;
  public type AvatarIDBasicInfo = Nat;
  public type LevelBasicInfo = Nat;
  public type EloBasicInfo = Float;
  public type VerificationBadgeBasicInfo = Bool;
  public type TitleBasicInfo = Text;
  public type DescriptionBasicInfo = Text;
  public type CountryBasicInfo = Text;
  public type SocialConnection = Types.SocialConnection;
  public type Platform = Types.Platform;
  public type Notification = Types.Notification;
  public type UserProfile = Types.UserProfile;
  public type UserNetwork = Types.UserNetwork;
  public type AIFeatures = Types.AIFeatures;
  public type FriendDetails = Types.FriendDetails;
  public type FriendRequest = Types.FriendRequest;
  public type Comment = Types.Comment;
  public type Post = Types.Post;
  public type Like = Types.Like;

  stable var _userProfile : [(UserID, UserProfile)] = [];
  var userProfile : HashMap.HashMap<UserID, UserProfile> = HashMap.fromIter(
    _userProfile.vals(),
    0,
    Principal.equal,
    Principal.hash,
  );
  stable var _userBasicInfo : [(UserID, UserBasicInfo)] = [];
  var userBasicInfo : HashMap.HashMap<UserID, UserBasicInfo> = HashMap.fromIter(
    _userBasicInfo.vals(),
    0,
    Principal.equal,
    Principal.hash,
  );
  stable var _userNetwork : [(UserID, UserNetwork)] = [];
  var userNetwork : HashMap.HashMap<UserID, UserNetwork> = HashMap.fromIter(
    _userNetwork.vals(),
    0,
    Principal.equal,
    Principal.hash,
  );

  public func reinitializeVariables() : async () {

    _referrals := [];
    referrals := HashMap.fromIter(
      _referrals.vals(),
      0,
      Principal.equal,
      Principal.hash,
    );

    _userProfile := [];
    userProfile := HashMap.fromIter(
      _userProfile.vals(),
      0,
      Principal.equal,
      Principal.hash,
    );

    _userBasicInfo := [];
    userBasicInfo := HashMap.fromIter(
      _userBasicInfo.vals(),
      0,
      Principal.equal,
      Principal.hash,
    );

    _userNetwork := [];
    userNetwork := HashMap.fromIter(
      _userNetwork.vals(),
      0,
      Principal.equal,
      Principal.hash,
    );
  };

  //////////  Register  //////////

  public shared ({ caller : UserID }) func signup(
    username : Text,
    avatarId : Nat,
    code : Text,
  ) : async (Bool, Text)
   {
    switch (userBasicInfo.get(caller)) {
      case (?_) {
        return (false, "User is already registered");
      };
      case (null) {

        let registrationDate = Time.now();
        let newPlayer : UserBasicInfo = {
          id = caller;
          username = username;
          avatarId = avatarId;
          level = 0;
          elo = 1200.0;
          verificationBadge = false;
          title = ?("title");
          description = ?("description") ;
          country = ?("country");
          registrationDate = registrationDate;
        };
      
        let newUserNetwork : UserNetwork = {
 
          notifications = ?[];

          connections = [{
            platform = #Cosmicrafts;
            username = username;
            profileLink = "/profile/username-uuid";
            memberSince = registrationDate;
          }];

          friends = ?[];
          friendRequests = ?[];
          mutualFriends = ?[];
          blockedUsers = ?[];
          following = ?[];
          followers = ?[];
          posts = ?[];
          comments = ?[];
          likes = ?[];
        };

        let (success, text) = await linkReferral(caller, username, code);

        if (not success) {
          return (false, text);
        };

        // let result = await initAchievements();

        userNetwork.put(caller, newUserNetwork);
        userBasicInfo.put(caller, newPlayer);

        return (true, "User registered successfully");
      };
    };
  };

  public func signupByID(
    userId : Principal,
    username : Text,
    avatarId : Nat,
    code : Text,
    ) : async (Bool, Text) {
    switch (userBasicInfo.get(userId)) {
      case (?_) {
        return (false, "User is already registered");
      };
      case (null) {

        let registrationDate = Time.now();
      
        let newPlayer : UserBasicInfo = {
          id = userId;
          username = username;
          avatarId = avatarId;
          level = 0;
          elo = 1200.0;
          verificationBadge = false;
          title = ?("title");
          description = ?("description") ;
          country = ?("country");
          registrationDate = registrationDate;
        };

        let newUserNetwork : UserNetwork = {

          notifications = ?[];

          connections = [{
            platform = #Cosmicrafts;
            username = username;
            profileLink = "/profile/username-uuid";
            memberSince = registrationDate;
          }];

          friends = ?[];
          friendRequests = ?[];
          mutualFriends = ?[];
          blockedUsers = ?[];
          following = ?[];
          followers = ?[];
          posts = ?[];
          comments = ?[];
          likes = ?[];
        };

        let (success, text) = await linkReferral(userId, username, code);

        if (not success) {
          return (false, text);
        };

        // let result = await initAchievements();
        // createMissionsPeriodically


        // some nfts mintNFT
        // stats

        userNetwork.put(userId, newUserNetwork);
        userBasicInfo.put(userId, newPlayer);

        return (true, "User registered successfully");
      };
    };
  };

  public query ({ caller }) func userExists() : async Bool {
    switch (userBasicInfo.get(caller)) {
      case null { return false };
      case (?_) { return true };
    };
  };

  //////////  User Profile  //////////

  public query ({ caller }) func getUserProfileByCaller() 
    : async ?UserProfile {
    return userProfile.get(caller);
  };

  public query func getUserProfileByID(id : UserID) 
    : async ?UserProfile {
    return userProfile.get(id);
  };

  //////////  User Basic Info  //////////

  public query ({ caller }) func getUserBasicInfo() 
    : async ?UserBasicInfo {
    return userBasicInfo.get(caller);
  };

  public query func getUserBasicInfoByID(id : UserID) 
    : async ?UserBasicInfo {
    return userBasicInfo.get(id);
  };

  public query func getAllUsersBasicInfo() 
    : async [UserBasicInfo] {
    return Iter.toArray(userBasicInfo.vals());
  };
 
  public shared ({ caller }) func updateUserBasicInfo(
    newUsername : ?UserNameBasicInfo,
    newAvatarId : ?AvatarIDBasicInfo,
    newLevel : ?LevelBasicInfo,
    newElo : ?EloBasicInfo,
    newVerificationBadge : ?VerificationBadgeBasicInfo,
    newTitle : ?TitleBasicInfo,
    newDescription : ?DescriptionBasicInfo,
    newCountry : ?CountryBasicInfo,
    ) : async (Bool, Text) {

    switch (userBasicInfo.get(caller)) {
      case (null) return (false, "User not found");
      case (?info) {
        let updatedInfo = {
          id = info.id;
          registrationDate = info.registrationDate;
          username = switch (newUsername) {
            case (?value) value;
            case (null) info.username;
          };
          avatarId = switch (newAvatarId) {
            case (?value) value;
            case (null) info.avatarId;
          };
          level = switch (newLevel) {
            case (?value) value;
            case (null) info.level;
          };
          elo = switch (newElo) {
            case (?value) value;
            case (null) info.elo;
          };
          verificationBadge = switch (newVerificationBadge) {
            case (?value) value;
            case (null) info.verificationBadge;
          };
          title = switch (newTitle) {
            case (?value) ?value;
            case (null) info.title;
          };
          description = switch (newDescription) {
            case (?value) ?value;
            case (null) info.description;
          };
          country = switch (newCountry) {
            case (?value) ?value;
            case (null) info.country;
          };
        };
        userBasicInfo.put(caller, updatedInfo);
        return (true, "User updated successfully");
      };
    };
  };

  //////////  User Network  //////////

  public func getUserNetworkByID(id : UserID) 
    : async ?UserNetwork {
    return userNetwork.get(id);
  };

  public query({caller}) func getUserNetwork() 
  : async ?UserNetwork {
    return userNetwork.get(caller);
  };

  public func sendFriendRequests(
    id: Principal, 
    request : [FriendRequest]) 
    : async (Bool, Text) {   
    for (req in Iter.fromArray(request)) {
      switch (userNetwork.get(req)) {
        case (null) {
          return (false, "No network found");};
        case (?network) {
          switch (network.friendRequests) {
            case (null) { 
              let updatedUserNetwork = {
                network with
                friendRequests = ?[id];
              }; 
              userNetwork.put(req, 
                updatedUserNetwork);
              return ( true,
              "Network updated" 
              );
            };
            case (?friendRequests) {
              let updatedRequests = 
              Array.append<FriendRequest>(
                friendRequests,[id]);
              let updatedUserNetwork = {
                network with
                friendRequests = 
                ?updatedRequests;
              };
              userNetwork.put(req, 
              updatedUserNetwork);
              return ( true,
              "Network Updated" 
              )
            };
          };
        };
      };
    };
    Debug.print("No valid requests processed.");
    return (false, "No valid requests processed.")
  };
  
  public func acceptFriendReqByID(
    userId : Principal, fromID : UserID
      ) : async (Bool, Text) {
      switch (userBasicInfo.get(fromID)) {
        case null (false, "User not found");
        case (?_) {let (success, t) = 
          await addFriend(userId, fromID);
            if(success){ 
              (true, t)
            } else {
          (false,t)
        };
      };
    };
  };
 
  private func addFriend(
    id: Principal, friendId : UserID) 
    : async (Bool, Text) {
      let friend = switch 
      (userBasicInfo.get(friendId)) {
        case null return (false, 
          "not found");
            case (?friend) {
              friend;
            };
          };
        let newFriend : FriendDetails = {
          id = friendId;
          username = friend.username;
          avatar = friend.avatarId;
          friendProfile = null;
        };
        switch (userNetwork.get(id)) {
          case (null) 
          return (false, 
          "userNetwork not found");
          case (?network) {
            switch (network.friends) {
              case (null) return (
              false, "network.friends null");
              case (?friends) {
                let updFriends = 
                Array.append<FriendDetails>(
                friends,[newFriend]);
                let updUserNetwork = {
                  network with
                  friends = ?updFriends
                };
                userNetwork.put(
                id, updUserNetwork);
                return (
              true, 
            "Friend added"
            );
          };
        };
      };
    };
  };

  public func deleteFriendReqByID(
    userId : Principal, fromID : UserID) 
    : async (Bool, Text) {switch 
      (userNetwork.get(fromID)) {
        case null {
          (false, "User not found")};
          case (?network) {
            switch (network.friendRequests) {
              case null {
                (false, 
                  "No friend requests found")};
                  case (?reqs) {
                    let updRequests = 
                      Array.filter<FriendRequest>(
                      reqs,
                      func(request) {
                      request != userId;
                      });
                      let updNetwork = {
                        network with
                        reqs = ?updRequests
                      };
                      userNetwork.put(
                     fromID,
                    updNetwork,
                    );
                  return (
                true, 
              "Deleted"
            );
          };
        };
      };
    };
  };  

  public func deleteFriend(
    caller : Principal, 
    deleteId : UserID
    ) : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.friends) {
          case (null) return false;
          case (?networkFriends) {
            let updatedFriends = 
            Array.filter<FriendDetails>(
              networkFriends,
              func(friend) {
                friend.id != deleteId;
              },
            );
            let updatedUserNetwork = {
              network with
              friends = ?updatedFriends
            };
            userNetwork.put(
              caller,
              updatedUserNetwork,
            );
            return true;
          };
        };
      };
    };
  };

  public query ({ caller }) func getAllFriends(page : Nat) 
    : async ?[FriendDetails] {
    switch (userNetwork.get(caller)) {
      case (null) return null;
      case (?userNetwork) {
        switch (userNetwork.friends) {
          case (null) return null;
          case (?friends) {
            let start = page * 10;
            let end = if (
              (page + 1) * 10 < friends.size()
            ) (page + 1) * 10 else friends.size();
            if (start >= friends.size()) (return null);
            ?Iter.toArray(
              Array.slice<FriendDetails>(
                friends,
                start,
                end,
              )
            );
          };
        };
      };
    };
  };

  public shared({caller}) func createPost(
    images : ?[Nat],
    content : Text,
    ) : async Int {

    let user : ?UserBasicInfo = userBasicInfo.get(caller);
    let basicInfo :UserBasicInfo = switch (user) {
      case null {return -1};
      case (?info) {info};
    };

    switch (userNetwork.get(caller)) {
      case (null) return -1;
      case (?network) {
        switch (network.posts) {
          case (null) return -1;
          case (?posts) {
            let postCount = posts.size() + 1;
            let newPost : Post = {
              id = postCount;
              userId = caller;
              username = basicInfo.username;
              images = switch (images) {
                case (?images) ?images;
                case (null) ?[];
              };
              content = content;
              timestamp = Time.now();
              likes = ?[];
              comments = ?[];
            };
            let updatedPosts = Array.append<Post>(
              posts,
              [newPost],
            );
            let updatedUserNetwork = {
              network with
              posts = ?updatedPosts
            };
            userNetwork.put(
              caller,
              updatedUserNetwork,
            );
            return postCount;
          };
        };
      };
    };
  };

  public shared({caller}) func createPostByID(
    id : Principal,
    images : ?[Nat],
    content : Text,
    ) : async  (Bool, Int, Text) {

    let user : ?UserBasicInfo = userBasicInfo.get(id);
    let basicInfo :UserBasicInfo = switch (user) {
      case null {return  (false, -1, "userBasicInfo.get(id) NULL")};
      case (?info) {info};
    };

    switch (userNetwork.get(id)) {
      case (null) {
        return  (false, -1, "userNetwork.get(id) NULL")};
      case (?network) {
        switch (network.posts) {
          case (null) {return  (false, -1, "network.posts")};
          case (?posts) {
            let postCount = posts.size() + 1;
            let newPost : Post = {
              id = postCount;
              userId = caller;
              username = basicInfo.username;
              images = switch (images) {
                case (?images) ?images;
                case (null) ?[];
              };
              content = content;
              timestamp = Time.now();
              likes = ?[];
              comments = ?[];
            };
            let updatedPosts = Array.append<Post>(
              posts,
              [newPost],
            );
            let updatedUserNetwork = {
              network with
              posts = ?updatedPosts
            };
            userNetwork.put(
              id,
              updatedUserNetwork,
            );
           return  (true, postCount, "Post created");
          };
        };
      };
    };
  };

  public query ({ caller }) func getPost(postId : Nat) 
    : async ?Post {
    switch (userNetwork.get(caller)) {
      case (null) null;
      case (?network) {
        switch (network.posts) {
          case (null) null;
          case (?posts) {
            let postOpt = 
            Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            postOpt;
          };
        };
      };
    };
  };

  public shared ({ caller }) func updatePost(postId : Nat, newContent : Text) 
    : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.posts) {
          case (null) return false;
          case (?posts) {
            if (postId >= posts.size() or posts[postId].userId != caller) {
              return false; // Invalid index or not the author
            };
            let updatedPost = {
              posts[postId] with
              content = newContent;
              timestamp = Time.now(); // Update the timestamp to the current time
            };
            let filteredPosts = Array.filter<Post>(
              posts,
              func(post : Post) : Bool {
                post.id != postId;
              },
            );
            let updatedPosts = Array.append(filteredPosts, [updatedPost]);
            let updatedNetwork = {
              network with
              posts = ?updatedPosts;
            };
            userNetwork.put(caller, updatedNetwork);
            return true;
          };
        };
      };
    };
  };

  public shared ({ caller }) func deletePost(postId : Nat) 
  : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.posts) {
          case (null) return false;
          case (?posts) {
            let updatedPosts = Array.filter<Post>(
              posts,
              func(post : Post) : Bool {
                post.id != postId;
              },
            );
            let updatedNetwork = {
              network with
              posts = ?updatedPosts;
            };
            userNetwork.put(caller, updatedNetwork);
            return true;
          };
        };
      };
    };
  };

  // Create a comment in a post
  public shared func createComment(
    postId : Nat,
    postOwnerId : UserID,
    commentCreatorId : UserID,
    content : Text,
    ) : async (Bool, Int, Text) {

    switch (userNetwork.get(postOwnerId)) {
      case (null) return (false, -1, "userNetwork.get(postOwnerId) NULL");
      case (?network) {
        switch (network.posts) {
          case (null) return return (false, -1, "network.posts NULL");
          case (?posts) {
            
            let postOpt = Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            switch (postOpt) {
              case (null) return (false, -1, "let postOpt = Array.find<Post> NULL");
              case (?post) {
                
                let info = userBasicInfo.get(commentCreatorId);
                let userInfo = switch (info) {
                  case null {return (false, -1, "let info = userBasicInfo.get(commentCreatorId) NULL")};
                  case (?info) {info};
                };
                var comments = switch(post.comments) {
                  case null {[]};
                  case (?comments) {comments}
                };
                let commentCount = comments.size() + 1;

                let newComment : Comment = {
                  id = commentCount;
                  postId = postId;
                  fromUserID = commentCreatorId;
                  fromUsername = userInfo.username;
                  content = content;
                  timestamp = Time.now();
                  likes = ?[];
                };

                let updatedPost = {
                  post with
                  comments = ?Array.append<Comment>(
                    comments,
                    [newComment],
                  )
                };
                let updatedPosts = Array.map<Post, Post>(
                  posts,
                  func(p : Post) : Post {
                    if (p.id == postId) updatedPost else p;
                  },
                );
                let updatedUserNetwork = {
                  network with
                  posts = ?updatedPosts;
                };
                userNetwork.put(postOwnerId, updatedUserNetwork);
                return (true, commentCount, "Comment created successfully");
              };
            };
          };
        };
      };
    };
  };

  // Give a like to post
  public func likePost(
    postId : Nat,
    postCreatorUserId : UserID,
    userLikerId : UserID,
    ) : async Bool {
    switch (userNetwork.get(postCreatorUserId)) {
      case (null) return false;
      case (?network) {
        switch (network.posts) {
          case (null) return false;
          case (?posts) {
            let postOpt = Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            switch (postOpt) {
              case (null) return false;
              case (?post) {

                let likes : [Like] = switch (postOpt) {
                  case (null) {return false};
                  case (?post) {
                    let likes = switch(post.likes) {
                      case null {[]};
                      case (?likeArray) {likeArray}
                    };
                  };
                };
                let fromUsername = switch (userBasicInfo.get(userLikerId)) {
                  case (null) {return false};
                  case (?info) {info.username};
                };
                let likeId = likes.size() + 1;
                let newLike : Like = {
                  id = likeId;
                  fromUserID = userLikerId;
                  likeVariant = #Post;
                  fromUsername = fromUsername;
                  timestamp = Time.now();
                };
                let updatedLikes = switch (post.likes) {
                  case (null) [newLike];
                  case (?likes) Array.append<Like>(likes, [newLike]);
                };
                let updatedPost = {
                  post with
                  likes = ?updatedLikes
                };
                let updatedPosts = Array.map<Post, Post>(
                  posts,
                  func(p : Post) : Post {
                    if (p.id == postId) updatedPost else p;
                  },
                );
                let updatedUserNetwork = {
                  network with
                  posts = ?updatedPosts
                };
                userNetwork.put(postCreatorUserId, updatedUserNetwork);
                return true;
              };
            };
          };
        };
      };
    };
  };

  // Give a like to comment
  public func likeComment(
    postId : Nat,
    postCreatorUserId : UserID,
    commentId : Nat,
    userLikerId : UserID,
    ) : async Bool {

    switch (userNetwork.get(postCreatorUserId)) {
      case (null) return false;
      case (?network) {
        switch (network.posts) {
          case (null) return false;
          case (?posts) {
            let postOpt = Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            switch (postOpt) {
              case (null) return false;
              case (?post) {
                let commentOpt = switch (post.comments) {
                  case (null) null;
                  case (?comments) Array.find<Comment>(
                    comments,
                    func(comment) {
                      comment.id == commentId;
                    },
                  );
                };
                switch (commentOpt) {
                  case (null) return false;
                  case (?comment) {
                    let likes : [Like] = switch (postOpt) {
                  case (null) {return false};
                  case (?post) {
                    let likes = switch(post.likes) {
                      case null {[]};
                      case (?likeArray) {likeArray}
                    };
                  };
                };
                let fromUsername = switch (userBasicInfo.get(userLikerId)) {
                  case (null) {return false};
                  case (?info) {info.username};
                };
                let likeId = likes.size() + 1;
                   let newLike : Like = {
                      id = likeId;
                      fromUserID = userLikerId;
                      likeVariant = #Comment;
                      fromUsername = fromUsername;
                      timestamp = Time.now();
                    };
                    let updatedLikes = switch (comment.likes) {
                      case (null) [newLike];
                      case (?likes) Array.append<Like>(likes, [newLike]);
                    };
                    let updatedComment = {
                      comment with
                      likes = ?updatedLikes
                    };
                    switch (post.comments) {
                      case (null) return false;
                      case (?comments) {
                        let updatedComments = Array.map<Comment, Comment>(
                          comments,
                          func(c : Comment) : Comment {
                            if (c.id == commentId) updatedComment else c;
                          },
                        );
                        let updatedPost = {
                          post with
                          comments = ?updatedComments
                        };
                        let updatedPosts = Array.map<Post, Post>(
                          posts,
                          func(p : Post) : Post {
                            if (p.id == postId) updatedPost else p;
                          },
                        );
                        let updatedUserNetwork = {
                          network with
                          posts = ?updatedPosts
                        };
                        userNetwork.put(postCreatorUserId, updatedUserNetwork);
                        return true;
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  // Unlike from a post 
  public shared ({ caller }) func unLikeFromPost(postId : Nat, likeId : Nat) 
    : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.posts) {
          case (null) return false;
          case (?posts) {
            let postOpt = 
            Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            switch (postOpt) {
              case (null) return false;
              case (?post) {
                switch (post.likes) {
                  case (null) return false;
                  case (?likes) {
                    let updatedLikes = 
                    Array.filter<Like>(
                      likes,
                      func(like : Like) : Bool {
                        like.id != likeId;
                      },
                    );
                    let updatedPost = {
                      post with
                      likes = ?updatedLikes;
                    };
                    let updatedPosts = 
                    Array.map<Post, Post>(
                      posts,
                      func(p : Post) : Post {
                        if (p.id == postId) 
                          updatedPost else p;
                      },
                    );
                    let updatedNetwork = {
                      network with
                      posts = ?updatedPosts;
                    };
                    userNetwork.put(
                      caller, 
                      updatedNetwork
                    );
                    true;
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  // Get all likes from a post 
  public query ({ caller }) func likesFromPost(postId : Nat) 
    : async ?[Like] {
    let userNetworkOpt = 
    userNetwork.get(caller);
    switch (userNetworkOpt) {
      case (null) return null;
      case (?network) {
        switch (network.posts) {
          case (null) return null;
          case (?posts) {
            let postOpt = 
            Array.find<Post>(
              posts,
              func(post) {
                post.id == postId;
              },
            );
            switch (postOpt) {
              case (null) return null;
              case (?post) {
                return post.likes;
              };
            };
          };
        };
      };
    };
  };

  // Block a user by user ID
  public shared ({ caller }) func blockUser(userIdToBlock : UserID) 
    : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.blockedUsers) {
          case (null) return false;
          case (?blockedUsers) {
            let updblocked = 
            Array.append<UserID>(
              blockedUsers,
              [userIdToBlock],
            );
            let updatedUserNetwork = {
              network with
              blockedUsers = ?updblocked
            };
            userNetwork.put(
              caller,
              updatedUserNetwork,
            );
            return true;
          };
        };
      };
    };
  };

  // Block an array of users by user ID
  public shared func blockUsers(key : Principal, idsToBlock : [UserID]) 
    : async Bool {
    switch (userNetwork.get(key)) {
      case (null) return false;
      case (?network) {
        switch (network.blockedUsers) {
          case (null) return false;
          case (?blockedUsers) {
            let update = 
            Array.append<UserID>(
              blockedUsers,
              idsToBlock,
          );
            userNetwork.put(key, {
              network with
              blockedUsers = ?update
            });
            return true;
          };
        };
      };
    };
  };

  // Unblock a user by user ID
  public func unblockUser(caller : Principal, idsToBlock : UserID) 
    : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.blockedUsers) {
          case (null) return false;
          case (?blockedUsers) {
            let updatedBlockedUsers = 
            Array.filter<UserID>(
              blockedUsers,
              func(userId) {
                userId != idsToBlock;
              },
            );
            let updatedUserNetwork = {
              network with
              blockedUsers = ?updatedBlockedUsers
            };
            userNetwork.put(
              caller,
              updatedUserNetwork,
            );
            return true;
          };
        };
      };
    };
  };

  // Get the blocked users with pagination
  public query ({ caller }) func getBlockedUsers(page : Nat) 
    : async ?[UserID] {
    switch (userNetwork.get(caller)) {
      case (null) return null;
      case (?network) {
        switch (network.blockedUsers) {
          case (null) return null;
          case (?blockedUsers) {
            let startIndex = page * 10;
            let endIndex = if (
              (page + 1) * 10 < blockedUsers.size()
            ) (page + 1) * 10 else blockedUsers.size();
            if (startIndex >= blockedUsers.size()) 
              return null;
            ?Iter.toArray(
              Array.slice<UserID>(
                blockedUsers,
                startIndex,
                endIndex,
              )
            );
          };
        };
      };
    };
  };

  // Get the blocked users by user ID
  public query func getBlockedUsersByID(id:Principal, page : Nat) 
    : async ?[UserID] {
    switch (userNetwork.get(id)) {
      case (null) return null;
      case (?network) {
        switch (network.blockedUsers) {
          case (null) return null;
          case (?blockedUsers) {
            let startIndex = page * 10;
            let endIndex = if (
              (page + 1) * 10 < blockedUsers.size()
            ) (page + 1) * 10 else blockedUsers.size();
            if (startIndex >= blockedUsers.size()) 
              return null;
            ?Iter.toArray(
              Array.slice<UserID>(
                blockedUsers,
                startIndex,
                endIndex,
              )
            );
          };
        };
      };
    };
  };

  // Follow a list of users by user ID as parameter
  public shared func followUsers(key : Principal, followIds : [UserID]) 
    : async Bool {
    switch (userNetwork.get(key)) {
      case (null) return false;
      case (?network) {
        switch (network.following) {
          case (null) return false;
          case (?following) {
            let update = 
            Array.append<UserID>(
              following,
              followIds,
            );
            userNetwork.put(key, {
              network with
              following = ?update
            });
            for (id in Iter.fromArray(followIds)) {
              switch (userNetwork.get(id)) {
                case (null) return false;
                case (?network) {
                  switch (network.followers) {
                    case (null) return false;
                    case (?followers) {
                      let updatedFollowers = 
                      Array.append<UserID>(
                        followers,
                        [key],
                      );
                      let updatedUserNetwork = {
                        network with
                        followers = ?updatedFollowers
                      };
                      userNetwork.put(
                        id,
                        updatedUserNetwork,
                      );
                    };
                  };
                };
              };
            };
            true;
          };
        };
      };
    };
  };

  // Unfollow a user by user ID
  public shared ({ caller }) func unfollowUser(unfollowId : UserID) 
    : async Bool {
    switch (userNetwork.get(caller)) {
      case (null) return false;
      case (?network) {
        switch (network.following) {
          case (null) return false;
          case (?following) {
            let updatedFollowing = Array.filter<UserID>(
              following,
              func(followId) {
                followId != unfollowId;
              },
            );
            let updatedUserNetwork = {
              network with
              following = ?updatedFollowing
            };
            userNetwork.put(
              caller,
              updatedUserNetwork,
            );
            return true;
          };
        };
      };
    };
  };

  // Get whos following the user
  public query ({ caller }) func getFollowing(page : Nat) 
    : async ?[UserID] {
    switch (userNetwork.get(caller)) {
      case (null) return null;
      case (?network) {
        switch (network.following) {
          case (null) return null;
          case (?following) {
            let startIndex = page * 10;
            let endIndex = if (
              (page + 1) * 10 < following.size()
            ) (page + 1) * 10 else following.size();
            if (startIndex >= following.size()) {
              return null;
            };
            ?Iter.toArray(
              Array.slice<UserID>(
                following,
                startIndex,
                endIndex,
              )
            );
          };
        };
      };
    };
  };

  // Get the Followers the user has
  public query ({ caller }) func getFollowers(page : Nat) 
    : async ?[UserID] {
    switch (userNetwork.get(caller)) {
      case (null) return null;
      case (?network) {
        switch (network.followers) {
          case (null) return null;
          case (?followers) {
            let startIndex = page * 10;
            let endIndex = if (
              (page + 1) * 10 < followers.size()
            ) (page + 1) * 10 else followers.size();
            if (startIndex >= followers.size()) {
              return null;
            };
            ?Iter.toArray(
              Array.slice<UserID>(
                followers,
                startIndex,
                endIndex,
              )
            );
          };
        };
      };
    };
  };

  // create a new notification 
  public func createNotification(
    nots : Notification
    ) : async Bool {
      switch (nots.to) {
        case (#FriendRequest(id)) {
          switch (userNetwork.get(id)) {
            case (null) return false;
            case (?network) {
              switch (network.notifications) {
                case (null) return false;
                case (?notifications) {
                  let nCount = notifications.size() + 1;
                  let updatedNots = 
                  Array.append<Notification>(
                    notifications, [{
                      id = ?nCount;
                      from = nots.from;
                      to = nots.to;
                      body = nots.body;
                      timestamp = ?Time.now();
                    }],
                  );
                  let updNetwork = {            
                    network with
                    notifications = 
                    ?updatedNots
                  };
                  userNetwork.put(
                  id, updNetwork);
                true;
              };
            };
          };
        };
      };
    };
  };

    

  // Get all notifications
  public query ({ caller }) func getAllNotifications(page : Nat) 
    : async ?[Notification] 
    {
      switch (userNetwork.get(caller)) {
        case (null) return null;
        case (?network) {
          switch (network.notifications) {
            case (null) return null;
            case (?notifications) {
              let startIndex = page * 10;
              let endIndex = if (
                (page + 1) * 10 < notifications.size()
                ) (page + 1) * 10 else notifications.size();
                if (startIndex >= notifications.size()) {
                  return null;
                };
                ?Iter.toArray(
              Array.slice<Notification>(
              notifications,
              startIndex,
              endIndex)
            );
          };
        };
      };
    };
  };


  // #endregion

  //#region |MatchMaking|
  stable var _matchID : Nat = 0;
  var inactiveSeconds : Nat64 = 30 * 1000; //check the value

  stable var _searching : [(MatchID, MatchData)] = [];
  var searching : HashMap.HashMap<MatchID, MatchData> = HashMap.fromIter(_searching.vals(), 0, Utils._natEqual, Utils._natHash);

  stable var _playerStatus : [(PlayerId, MMPlayerStatus)] = [];
  var playerStatus : HashMap.HashMap<PlayerId, MMPlayerStatus> = HashMap.fromIter(_playerStatus.vals(), 0, Principal.equal, Principal.hash);

  stable var _inProgress : [(MatchID, MatchData)] = [];
  var inProgress : HashMap.HashMap<MatchID, MatchData> = HashMap.fromIter(_inProgress.vals(), 0, Utils._natEqual, Utils._natHash);

  stable var _finishedGames : [(MatchID, MatchData)] = [];
  var finishedGames : HashMap.HashMap<MatchID, MatchData> = HashMap.fromIter(_finishedGames.vals(), 0, Utils._natEqual, Utils._natHash);

  public shared (msg) func getMatchSearching() : async (MMSearchStatus, Nat, Text) {
    assert (Principal.notEqual(msg.caller, NULL_PRINCIPAL));
    assert (Principal.notEqual(msg.caller, ANON_PRINCIPAL));
    let _now : Nat64 = Nat64.fromIntWrap(Time.now());
    let _pELO : Float = await getPlayerElo(msg.caller);

    // Retrieve the player's stored deck
    let playerDeckOpt = await getPlayerDeck(msg.caller);

    // If no deck is found or the deck is empty, return an error
    let deck = switch (playerDeckOpt) {
      case (null) {
        return (#NotAvailable, 0, "No stored deck found for this player.");
      };
      case (?deck) {
        if (deck.size() == 0) {
          return (#NotAvailable, 0, "Stored deck is empty.");
        };
        deck;
      };
    };

    var _gamesByELO : [MatchData] = Iter.toArray(searching.vals());

    for (m in _gamesByELO.vals()) {
      if (m.player2 == null and Principal.notEqual(m.player1.id, msg.caller) and (m.player1.lastPlayerActive + inactiveSeconds) > _now) {
        let username = switch (userBasicInfo.get(msg.caller)) {
          case (null) { "" };
          case (?player) { player.username };
        };
        let _p2 : MMInfo = {
          id = msg.caller;
          elo = _pELO;
          matchAccepted = true;
          playerGameData = {
            deck = deck; // Use the retrieved deck
            // Add other relevant fields if necessary
          };
          lastPlayerActive = Nat64.fromIntWrap(Time.now());
          username = username;
        };
        let _p1 : MMInfo = {
          id = m.player1.id;
          elo = m.player1.elo;
          matchAccepted = true;
          playerGameData = m.player1.playerGameData;
          lastPlayerActive = m.player1.lastPlayerActive;
          username = m.player1.username;
        };
        let _gameData : MatchData = {
          matchID = m.matchID;
          player1 = _p1;
          player2 = ?_p2;
          status = #Accepted;
        };
        let _p_s : MMPlayerStatus = {
          status = #Accepted;
          matchID = m.matchID;
        };
        inProgress.put(m.matchID, _gameData);
        let _removedSearching = searching.remove(m.matchID);
        removePlayersFromSearching(m.player1.id, msg.caller, m.matchID);
        playerStatus.put(msg.caller, _p_s);
        playerStatus.put(m.player1.id, _p_s);
        return (#Assigned, m.matchID, "Game found");
      };
    };

    switch (playerStatus.get(msg.caller)) {
      case (null) {};
      case (?_p) {
        switch (_p.status) {
          case (#Searching) {
            let _active : Bool = activatePlayerSearching(msg.caller, _p.matchID);
            if (_active == true) {
              return (#Assigned, _p.matchID, "Searching for game");
            };
          };
          case (#Reserved) {};
          case (#Accepting) {};
          case (#Accepted) {};
          case (#InGame) {};
          case (#Ended) {};
        };
      };
    };

    _matchID := _matchID + 1;
    let username = switch (userBasicInfo.get(msg.caller)) {
      case (null) { "" };
      case (?player) { player.username };
    };
    let _player : MMInfo = {
      id = msg.caller;
      elo = _pELO;
      matchAccepted = false;
      playerGameData = {
        deck = deck; // Use the retrieved deck
        // Add other relevant fields if necessary
      };
      lastPlayerActive = Nat64.fromIntWrap(Time.now());
      username = username;
    };
    let _match : MatchData = {
      matchID = _matchID;
      player1 = _player;
      player2 = null;
      status = #Searching;
    };
    searching.put(_matchID, _match);
    let _ps : MMPlayerStatus = {
      status = #Searching;
      matchID = _matchID;
    };
    playerStatus.put(msg.caller, _ps);
    return (#Assigned, _matchID, "Lobby created");
  };

  public query func getPlayerElo(id : Principal) : async Float {
    return switch (userBasicInfo.get(id)) {
      case (null) {
        1200;
      };
      case (?player) {
        player.elo;
      };
    };
  };

  public shared (msg) func setPlayerActive() : async Bool {
    assert (Principal.notEqual(msg.caller, NULL_PRINCIPAL));
    assert (Principal.notEqual(msg.caller, ANON_PRINCIPAL));

    switch (playerStatus.get(msg.caller)) {
      case (null) { return false };
      case (?_ps) {
        switch (searching.get(_ps.matchID)) {
          case (null) { return false };
          case (?_m) {
            let _now = Nat64.fromIntWrap(Time.now());
            if (_m.player1.id == msg.caller) {
              if ((_m.player1.lastPlayerActive + inactiveSeconds) < _now) {
                return false;
              };
              let _p : MMInfo = _m.player1;
              let _p1 : MMInfo = structPlayerActiveNow(_p);
              let _gameData : MatchData = structMatchData(_p1, _m.player2, _m);
              searching.put(_m.matchID, _gameData);
              return true;
            } else {
              let _p : MMInfo = switch (_m.player2) {
                case (null) { return false };
                case (?_p) { _p };
              };
              if ((_p.lastPlayerActive + inactiveSeconds) < _now) {
                return false;
              };
              let _p2 : MMInfo = structPlayerActiveNow(_p);
              let _gameData : MatchData = structMatchData(_m.player1, ?_p2, _m);
              searching.put(_m.matchID, _gameData);
              return true;
            };
          };
        };
        return false;
      };
    };
  };

  func structPlayerActiveNow(_p1 : MMInfo) : MMInfo {
    let _p : MMInfo = {
      id = _p1.id;
      elo = _p1.elo;
      matchAccepted = _p1.matchAccepted;
      playerGameData = _p1.playerGameData;
      lastPlayerActive = Nat64.fromIntWrap(Time.now());
      username = _p1.username; // Use existing type
    };
    return _p;
  };

  func structMatchData(_p1 : MMInfo, _p2 : ?MMInfo, _m : MatchData) : MatchData {
    let _md : MatchData = {
      matchID = _m.matchID;
      player1 = _p1;
      player2 = _p2;
      status = _m.status;
    };
    return _md;
  };

  func activatePlayerSearching(player : Principal, matchID : Nat) : Bool {
    switch (searching.get(matchID)) {
      case (null) { return false };
      case (?_m) {
        if (_m.status != #Searching) {
          return false;
        };
        let _now = Nat64.fromIntWrap(Time.now());
        if (_m.player1.id == player) {
          /// Check if the time of expiration have passed already and return false
          if ((_m.player1.lastPlayerActive + inactiveSeconds) < _now) {
            return false;
          };
          let _p : MMInfo = _m.player1;
          let _p1 : MMInfo = structPlayerActiveNow(_p);
          let _gameData : MatchData = structMatchData(_p1, _m.player2, _m);
          searching.put(_m.matchID, _gameData);
          return true;
        } else {
          let _p : MMInfo = switch (_m.player2) {
            case (null) { return false };
            case (?_p) { _p };
          };
          if (player != _p.id) {
            return false;
          };
          if ((_p.lastPlayerActive + inactiveSeconds) < _now) {
            return false;
          };
          let _p2 : MMInfo = structPlayerActiveNow(_p);
          let _gameData : MatchData = structMatchData(_m.player1, ?_p2, _m);
          searching.put(_m.matchID, _gameData);
          return true;
        };
      };
    };
  };

  func removePlayersFromSearching(p1 : Principal, p2 : Principal, matchID : Nat) {
    switch (playerStatus.get(p1)) {
      case (null) {};
      case (?_p1) {
        if (_p1.matchID != matchID) {
          searching.delete(_p1.matchID);
        };
      };
    };
    switch (playerStatus.get(p2)) {
      case (null) {};
      case (?_p2) {
        if (_p2.matchID != matchID) {
          searching.delete(_p2.matchID);
        };
      };
    };
  };

  public shared (msg) func cancelMatchmaking() : async (Bool, Text) {
    assert (msg.caller != NULL_PRINCIPAL and msg.caller != ANON_PRINCIPAL);
    switch (playerStatus.get(msg.caller)) {
      case (null) {
        return (true, "Game not found for this player");
      };
      case (?_s) {
        if (_s.status == #Searching) {
          searching.delete(_s.matchID);
          playerStatus.delete(msg.caller);
          return (true, "Matchmaking canceled successfully");
        } else {
          return (false, "Match found, cannot cancel at this time");
        };
      };
    };
  };

  func getOtherPlayer(_m : MatchData, caller : Principal) : ?Principal {
    switch (_m.player1.id == caller) {
      case (true) {
        switch (_m.player2) {
          case (null) {
            return (null);
          };
          case (?_p2) {
            return (?_p2.id);
          };
        };
      };
      case (false) {
        return (?_m.player1.id);
      };
    };
  };

  public query func getPlayerStats(player : PlayerId) : async ?PlayerGamesStats {
    return playerGamesStats.get(player);
  };

  public query func getPlayerAverageStats(_player : Principal) : async ?AverageStats {
    switch (playerGamesStats.get(_player)) {
      case (null) {
        let _newAverageStats : AverageStats = {
          averageEnergyGenerated = 0;
          averageEnergyUsed = 0;
          averageEnergyWasted = 0;
          averageDamageDealt = 0;
          averageKills = 0;
          averageXpEarned = 0;
        };
        return ?_newAverageStats;
      };
      case (?_p) {
        let _averageStats : AverageStats = {
          averageEnergyGenerated = _p.energyGenerated / _p.gamesPlayed;
          averageEnergyUsed = _p.energyUsed / _p.gamesPlayed;
          averageEnergyWasted = _p.energyWasted / _p.gamesPlayed;
          averageDamageDealt = _p.totalDamageDealt / _p.gamesPlayed;
          averageKills = _p.totalKills / _p.gamesPlayed;
          averageXpEarned = _p.totalXpEarned / _p.gamesPlayed;
        };
        return ?_averageStats;
      };
    };
  };

  public query func getAllSearching() : async [MatchData] {
    let _searchingList = Buffer.Buffer<MatchData>(searching.size());
    for (m in searching.vals()) {
      _searchingList.add(m);
    };
    return Buffer.toArray(_searchingList);
  };

  public query (msg) func isGameMatched() : async (Bool, Text) {
    switch (playerStatus.get(msg.caller)) {
      case (null) {
        return (false, "Game not found for this player");
      };
      case (?_s) {
        switch (searching.get(_s.matchID)) {
          case (null) {
            switch (inProgress.get(_s.matchID)) {
              case (null) {
                return (false, "Game not found for this player");
              };
              case (?_m) {
                return (true, "Game matched");
              };
            };
          };
          case (?_m) {
            switch (_m.player2) {
              case (null) {
                return (false, "Not matched yet");
              };
              case (?_p2) {
                return (true, "Game matched");
              };
            };
          };
        };
      };
    };
  };

  public query func getMatchParticipants(matchID : MatchID) : async ?(Principal, ?Principal) {
    switch (finishedGames.get(matchID)) {
      case (null) {
        switch (inProgress.get(matchID)) {
          case (null) {
            switch (searching.get(matchID)) {
              case (null) { return null };
              case (?matchData) {
                let player2Id = switch (matchData.player2) {
                  case (null) { null };
                  case (?p) { ?p.id };
                };
                return ?(matchData.player1.id, player2Id);
              };
            };
          };
          case (?matchData) {
            let player2Id = switch (matchData.player2) {
              case (null) { null };
              case (?p) { ?p.id };
            };
            return ?(matchData.player1.id, player2Id);
          };
        };
      };
      case (?matchData) {
        let player2Id = switch (matchData.player2) {
          case (null) { null };
          case (?p) { ?p.id };
        };
        return ?(matchData.player1.id, player2Id);
      };
    };
  };

  public shared composite query (msg) func getMyMatchData() : async (?FullMatchData, Nat) {
    assert (msg.caller != NULL_PRINCIPAL and msg.caller != ANON_PRINCIPAL);
    switch (playerStatus.get(msg.caller)) {
      case (null) return (null, 0);
      case (?_s) {
        let _m = switch (searching.get(_s.matchID)) {
          case (null) switch (inProgress.get(_s.matchID)) {
            case (null) switch (finishedGames.get(_s.matchID)) {
              case (null) return (null, 0);
              case (?_m) _m;
            };
            case (?_m) _m;
          };
          case (?_m) _m;
        };

        let _p = if (_m.player1.id == msg.caller) 1 else switch (_m.player2) {
          case (null) return (null, 0);
          case (?_p2) 2;
        };

        let _p1Data = userBasicInfo.get(_m.player1.id);
        let _p1Name = switch (_p1Data) {
          case (null) "";
          case (?p1) p1.username;
        };
        let _p1Avatar = switch (_p1Data) {
          case (null) 0;
          case (?p1) p1.avatarId;
        };
        let _p1Level = switch (_p1Data) {
          case (null) 0;
          case (?p1) p1.level;
        };

        let _fullPlayer2 = switch (_m.player2) {
          case null null;
          case (?p2) {
            let _p2D = userBasicInfo.get(p2.id);
            ?{
              id = p2.id;
              username = switch (_p2D) {
                case (null) "";
                case (?p) p.username;
              };
              avatar = switch (_p2D) {
                case (null) 0;
                case (?p) p.avatarId;
              };
              level = switch (_p2D) {
                case (null) 0;
                case (?p) p.level;
              };
              matchAccepted = p2.matchAccepted;
              elo = p2.elo;
              playerGameData = p2.playerGameData;
            };
          };
        };

        let _fullPlayer1 = {
          id = _m.player1.id;
          username = _p1Name;
          avatar = _p1Avatar;
          level = _p1Level;
          matchAccepted = _m.player1.matchAccepted;
          elo = _m.player1.elo;
          playerGameData = _m.player1.playerGameData;
        };

        let fm : FullMatchData = {
          matchID = _m.matchID;
          player1 = _fullPlayer1;
          player2 = _fullPlayer2;
          status = _m.status;
        };

        return (?fm, _p);
      };
    };
  };

  public query func getMatchIDsByPrincipal(player : PlayerId) : async [MatchID] {
    let buffer = Buffer.Buffer<MatchID>(0);
    for ((matchID, matchData) in finishedGames.entries()) {
      if (matchData.player1.id == player) {
        buffer.add(matchID);
      } else {
        switch (matchData.player2) {
          case (null) {};
          case (?p2) {
            if (p2.id == player) {
              buffer.add(matchID);
            };
          };
        };
      };
    };
    return Buffer.toArray(buffer);
  };

  public query func getMatchStats(MatchID : MatchID) : async ?BasicStats {
    return basicStats.get(MatchID);
  };

  public query func getMatchDetails(matchID : MatchID) : async ?(MatchData, [(UserBasicInfo, PlayerGamesStats)]) {
    let matchDataOpt = switch (finishedGames.get(matchID)) {
      case (null) {
        switch (inProgress.get(matchID)) {
          case (null) {
            switch (searching.get(matchID)) {
              case (null) { return null };
              case (?matchData) { ?matchData };
            };
          };
          case (?matchData) { ?matchData };
        };
      };
      case (?matchData) { ?matchData };
    };

    switch (matchDataOpt) {
      case (null) { return null };
      case (?matchData) {
        let playerStats = Buffer.Buffer<(UserBasicInfo, PlayerGamesStats)>(2); // Assuming max 2 players

        switch (userBasicInfo.get(matchData.player1.id)) {
          case (null) {};
          case (?player1Data) {
            switch (playerGamesStats.get(matchData.player1.id)) {
              case (null) {};
              case (?player1Stats) {
                playerStats.add((player1Data, player1Stats));
              };
            };
          };
        };

        switch (matchData.player2) {
          case (null) {};
          case (?player2Info) {
            switch (userBasicInfo.get(player2Info.id)) {
              case (null) {};
              case (?player2Data) {
                switch (playerGamesStats.get(player2Info.id)) {
                  case (null) {};
                  case (?player2Stats) {
                    playerStats.add((player2Data, player2Stats));
                  };
                };
              };
            };
          };
        };

        return ?(matchData, Buffer.toArray(playerStats));
      };
    };
  };

  public query func getMatchHistoryByPrincipal(player : PlayerId) : async [(MatchID, ?BasicStats)] {
    let buffer = Buffer.Buffer<(MatchID, ?BasicStats)>(0);
    for ((matchID, matchData) in finishedGames.entries()) {
      if (matchData.player1.id == player) {
        let matchStats = basicStats.get(matchID);
        buffer.add((matchID, matchStats));
      } else {
        switch (matchData.player2) {
          case (null) {};
          case (?p2) {
            if (p2.id == player) {
              let matchStats = basicStats.get(matchID);
              buffer.add((matchID, matchStats));
            };
          };
        };
      };
    };
    return Buffer.toArray(buffer);
  };

  public query func getCosmicraftsStats() : async OverallStats {
    return overallStats;
  };

  public query func test(playerId : PlayerId) : async ?{
    username : Username;
    level : Level;
    elo : Float;
    xp : Nat;
    gamesWon : Nat;
    gamesLost : Nat;
  } {
    // Retrieve player details
    let playerOpt = userBasicInfo.get(playerId);
    let playerStatsOpt = playerGamesStats.get(playerId);

    switch (playerOpt, playerStatsOpt) {
      case (null, _) {
        // Player does not exist
        return null;
      };
      case (_, null) {
        // Player stats do not exist
        return null;
      };
      case (?player, ?stats) {
        // Gather the required data
        let result = {
          username = player.username;
          level = player.level;
          elo = player.elo;
          xp = stats.totalXpEarned;
          gamesWon = stats.gamesWon;
          gamesLost = stats.gamesLost;
        };

        return ?result;
      };
    };
  };
  // #endregion

  // #region |Statistics|
  stable var _basicStats : [(MatchID, BasicStats)] = [];
  var basicStats : HashMap.HashMap<MatchID, BasicStats> = HashMap.fromIter(_basicStats.vals(), 0, Utils._natEqual, Utils._natHash);

  stable var _playerGamesStats : [(PlayerId, PlayerGamesStats)] = [];
  var playerGamesStats : HashMap.HashMap<PlayerId, PlayerGamesStats> = HashMap.fromIter(_playerGamesStats.vals(), 0, Principal.equal, Principal.hash);

  stable var _onValidation : [(MatchID, BasicStats)] = [];
  var onValidation : HashMap.HashMap<MatchID, BasicStats> = HashMap.fromIter(_onValidation.vals(), 0, Utils._natEqual, Utils._natHash);

  stable var _countedMatches : [(MatchID, Bool)] = [];
  var countedMatches : HashMap.HashMap<MatchID, Bool> = HashMap.fromIter(_countedMatches.vals(), 0, Utils._natEqual, Utils._natHash);

  stable var overallStats : OverallStats = {
    totalGamesPlayed : Nat = 0;
    totalGamesSP : Nat = 0;
    totalGamesMP : Nat = 0;
    totalDamageDealt : Nat = 0;
    totalTimePlayed : Nat = 0;
    totalKills : Nat = 0;
    totalEnergyGenerated : Nat = 0;
    totalEnergyUsed : Nat = 0;
    totalEnergyWasted : Nat = 0;
    totalXpEarned : Nat = 0;
    totalGamesWithFaction : [GamesWithFaction] = [];
    totalGamesGameMode : [GamesWithGameMode] = [];
    totalGamesWithCharacter : [GamesWithCharacter] = [];
  };

  func _initializeNewPlayerStats(_player : Principal) : async (Bool, Text) {
    let _playerStats : PlayerGamesStats = {
      gamesPlayed = 0;
      gamesWon = 0;
      gamesLost = 0;
      energyGenerated = 0;
      energyUsed = 0;
      energyWasted = 0;
      totalDamageDealt = 0;
      totalDamageTaken = 0;
      totalDamageCrit = 0;
      totalDamageEvaded = 0;
      totalXpEarned = 0;
      totalKills = 0;
      totalGamesWithFaction = [];
      totalGamesGameMode = [];
      totalGamesWithCharacter = [];
    };
    playerGamesStats.put(_player, _playerStats);
    return (true, "Player stats initialized");
  };

  func updatePlayerELO(PlayerId : PlayerId, won : Nat, otherPlayerId : ?PlayerId) : async Bool {
    switch (otherPlayerId) {
      case (null) {
        return false;
      };
      case (?otherPlayer) {
        // Get both players' ELO
        var _p1Elo : Float = await getPlayerElo(PlayerId);
        let _p2Elo : Float = await getPlayerElo(otherPlayer);

        // Base K-Factor for ELO changes
        let baseKFactor : Float = 32.0;

        // Determine win and loss factors based on player's ELO
        let winFactor : Float = if (_p1Elo < 1400.0) 2.0 else if (_p1Elo < 1800.0) 1.75 else if (_p1Elo < 2200.0) 1.5 else if (_p1Elo < 2600.0) 1.25 else 1.0;

        let lossFactor : Float = if (_p1Elo < 1400.0) 0.1 else if (_p1Elo < 1800.0) 0.5 else if (_p1Elo < 2200.0) 1.0 else if (_p1Elo < 2600.0) 1.25 else 2.0;

        // Calculate expected win probability
        let _p1Expected : Float = 1 / (1 + Float.pow(10, (_p2Elo - _p1Elo) / 400));
        let _p2Expected : Float = 1 / (1 + Float.pow(10, (_p1Elo - _p2Elo) / 400));

        // Calculate ELO change
        let pointChange : Float = if (won == 1) baseKFactor * winFactor * (1 - _p1Expected) else -baseKFactor * lossFactor * _p1Expected;

        let _elo : Float = _p1Elo + pointChange;

        let _updated = await updateELOonPlayer(PlayerId, _elo);

        return _updated;
      };
    };
  };

  func updateELOonPlayer(playerId : Principal, newELO : Float) : async Bool {
    switch (userBasicInfo.get(playerId)) {
      case (null) {
        return false;
      };
      case (?existingPlayer) {
        let updatedPlayer : UserBasicInfo = {
          id = existingPlayer.id;
          username = existingPlayer.username;
          avatarId = existingPlayer.avatarId;
          level = existingPlayer.level;
          elo = newELO;
          verificationBadge = existingPlayer.verificationBadge;
          title = existingPlayer.title;
          description = existingPlayer.description;
          country = existingPlayer.country;
          registrationDate = existingPlayer.registrationDate;
        };
        userBasicInfo.put(playerId, updatedPlayer);
        return true;
      };
    };
  };

  func isCallerPartOfMatch(matchID : MatchID, caller : Principal) : async Bool {
    let matchParticipants = await getMatchParticipants(matchID);
    switch (matchParticipants) {
      case (null) { return false };
      case (?matchData) {
        if (matchData.0 == caller) {
          return true;
        };
        switch (matchData.1) {
          case (?player2) {
            if (player2 == caller) {
              return true;
            };
          };
          case (null) {};
        };
        return false;
      };
    };
  };

  public shared query (msg) func getMyStats() : async ?PlayerGamesStats {
    switch (playerGamesStats.get(msg.caller)) {
      case (null) {
        let _playerStats : PlayerGamesStats = {
          gamesPlayed = 0;
          gamesWon = 0;
          gamesLost = 0;
          energyGenerated = 0;
          energyUsed = 0;
          energyWasted = 0;
          totalDamageDealt = 0;
          totalDamageTaken = 0;
          totalDamageCrit = 0;
          totalDamageEvaded = 0;
          totalXpEarned = 0;
          totalKills = 0;
          totalGamesWithFaction = [];
          totalGamesGameMode = [];
          totalGamesWithCharacter = [];
        };
        return ?_playerStats;
      };
      case (?_p) {
        return playerGamesStats.get(msg.caller);
      };
    };
  };

  // #endregion

  //#region |Tournaments Matchmaking|

  stable var tournaments : [Tournament] = [];
  stable var matches : [Match] = [];
  stable var feedback : [{
    principal : Principal;
    tournamentId : Nat;
    feedback : Text;
  }] = [];
  stable var disputes : [{
    principal : Principal;
    matchId : Nat;
    reason : Text;
    status : Text;
  }] = [];

  type Tournament = {
    id : Nat;
    name : Text;
    startDate : Time.Time;
    prizePool : Text;
    expirationDate : Time.Time;
    participants : [Principal];
    registeredParticipants : [Principal];
    isActive : Bool;
    bracketCreated : Bool;
    matchCounter : Nat; // Add matchCounter to each tournament
  };

  type Match = {
    id : Nat;
    tournamentId : Nat;
    participants : [Principal];
    result : ?{ winner : Principal; score : Text };
    status : Text;
    nextMatchId : ?Nat; // Track the next match
  };

  public shared func createTournament(name : Text, startDate : Time.Time, prizePool : Text, expirationDate : Time.Time) : async Nat {

    let id = tournaments.size();
    let buffer = Buffer.Buffer<Tournament>(tournaments.size() + 1);
    for (tournament in tournaments.vals()) {
      buffer.add(tournament);
    };
    buffer.add({
      id = id;
      name = name;
      startDate = startDate;
      prizePool = prizePool;
      expirationDate = expirationDate;
      participants = [];
      registeredParticipants = [];
      isActive = true;
      bracketCreated = false;
      matchCounter = 0 // Initialize matchCounter
    });
    tournaments := Buffer.toArray(buffer);
    return id;
  };

  public shared ({ caller }) func joinTournament(tournamentId : Nat) : async Bool {
    if (tournamentId >= tournaments.size()) {
      return false;
    };

    let tournament = tournaments[tournamentId];

    if (Array.indexOf<Principal>(
      caller, tournament.participants, 
      func(a : Principal, b : Principal) : Bool { a == b }) != null)
       {
      return false;
    };

    var updatedParticipants = Buffer.Buffer<Principal>(tournament.participants.size() + 1);
    for (participant in tournament.participants.vals()) {
      updatedParticipants.add(participant);
    };
    updatedParticipants.add(caller);

    var updatedRegisteredParticipants = Buffer.Buffer<Principal>(tournament.registeredParticipants.size() + 1);
    for (participant in tournament.registeredParticipants.vals()) {
      updatedRegisteredParticipants.add(participant);
    };
    updatedRegisteredParticipants.add(caller);

    let updatedTournament = {
      id = tournament.id;
      name = tournament.name;
      startDate = tournament.startDate;
      prizePool = tournament.prizePool;
      expirationDate = tournament.expirationDate;
      participants = Buffer.toArray(updatedParticipants);
      registeredParticipants = Buffer.toArray(updatedRegisteredParticipants);
      isActive = tournament.isActive;
      bracketCreated = tournament.bracketCreated;
      matchCounter = tournament.matchCounter;
    };

    tournaments := Array.tabulate(
      tournaments.size(),
      func(i : Nat) : Tournament {
        if (i == tournamentId) {
          updatedTournament;
        } else {
          tournaments[i];
        };
      },
    );

    return true;
  };

  public query func getRegisteredUsers(tournamentId : Nat) : async [Principal] {
    if (tournamentId >= tournaments.size()) {
      return [];
    };

    let tournament : Tournament = tournaments[tournamentId];
    return tournament.registeredParticipants;
  };

  public shared ({ caller }) func submitFeedback(_tournamentId : Nat, feedbackText : Text) : async Bool {
    let newFeedback = Buffer.Buffer<{ principal : Principal; tournamentId : Nat; feedback : Text }>(feedback.size() + 1);
    for (entry in feedback.vals()) {
      newFeedback.add(entry);
    };
    newFeedback.add({
      principal = caller;
      tournamentId = _tournamentId;
      feedback = feedbackText;
    });
    feedback := Buffer.toArray(newFeedback);
    return true;
  };

  public shared ({ caller }) func submitMatchResult(tournamentId : Nat, matchId : Nat, score : Text) : async Bool {
    let matchOpt = Array.find<Match>(matches, func(m : Match) : Bool { m.id == matchId and m.tournamentId == tournamentId });
    switch (matchOpt) {
      case (?match) {
        let isParticipant = Array.find<Principal>(match.participants, func(p : Principal) : Bool { p == caller }) != null;
        if (not isParticipant) {
          return false;
        };

        var updatedMatches = Buffer.Buffer<Match>(matches.size());
        for (m in matches.vals()) {
          if (m.id == matchId and m.tournamentId == tournamentId) {
            updatedMatches.add({
              id = m.id;
              tournamentId = m.tournamentId;
              participants = m.participants;
              result = ?{ winner = caller; score = score };
              status = "pending verification";
              nextMatchId = m.nextMatchId;
            });
          } else {
            updatedMatches.add(m);
          };
        };
        matches := Buffer.toArray(updatedMatches);
        return true;
      };
      case null {
        return false;
      };
    };
  };

  public shared ({ caller }) func disputeMatch(tournamentId : Nat, matchId : Nat, reason : Text) : async Bool {
    let matchExists = Array.find(matches, func(m : Match) : Bool { m.id == matchId and m.tournamentId == tournamentId }) != null;
    if (not matchExists) {
      return false;
    };

    let newDispute = {
      principal = caller;
      matchId = matchId;
      reason = reason;
      status = "pending";
    };
    let updatedDisputes = Buffer.Buffer<{ principal : Principal; matchId : Nat; reason : Text; status : Text }>(disputes.size() + 1);
    for (dispute in disputes.vals()) {
      updatedDisputes.add(dispute);
    };
    updatedDisputes.add(newDispute);
    disputes := Buffer.toArray(updatedDisputes);

    return true;
  };

  public shared func adminUpdateMatch(tournamentId : Nat, matchId : Nat, winnerIndex : Nat, score : Text) : async Bool {
    let matchOpt = Array.find<Match>(matches, func(m : Match) : Bool { m.id == matchId and m.tournamentId == tournamentId });
    switch (matchOpt) {
      case (?match) {
        if (winnerIndex >= Array.size<Principal>(match.participants)) {
          return false; // Invalid winner index
        };

        let winnerPrincipal = match.participants[winnerIndex];

        var updatedMatches = Buffer.Buffer<Match>(matches.size());
        for (m in matches.vals()) {
          if (m.id == matchId and m.tournamentId == tournamentId) {
            updatedMatches.add({
              id = m.id;
              tournamentId = m.tournamentId;
              participants = m.participants;
              result = ?{
                winner = winnerPrincipal;
                score = score;
              };
              status = "verified";
              nextMatchId = m.nextMatchId;
            });
          } else {
            updatedMatches.add(m);
          };
        };
        matches := Buffer.toArray(updatedMatches);

        // Update the bracket directly by advancing the winner
        Debug.print("Admin verified match: " # Nat.toText(matchId) # " with winner: " # Principal.toText(winnerPrincipal));
        ignore updateBracketAfterMatchUpdate(match.tournamentId, match.id, winnerPrincipal);

        return true;
      };
      case null {
        return false;
      };
    };
  };

  private func log2(x : Nat) : Nat {
    var result = 0;
    var value = x;
    while (value > 1) {
      value /= 2;
      result += 1;
    };
    return result;
  };

  public shared func updateBracketAfterMatchUpdate(tournamentId : Nat, matchId : Nat, winner : Principal) : async () {
    Debug.print("Starting updateBracketAfterMatchUpdate");
    Debug.print("Updated Match ID: " # Nat.toText(matchId));
    Debug.print("Winner: " # Principal.toText(winner));

    // Log the current state of the matches
    for (i in Iter.range(0, matches.size() - 1)) {
      let match = matches[i];
      Debug.print("Current Match: " # matchToString(match));
    };

    let updatedMatchOpt = Array.find<Match>(matches, func(m : Match) : Bool { m.id == matchId and m.tournamentId == tournamentId });
    switch (updatedMatchOpt) {
      case (?updatedMatch) {
        switch (updatedMatch.nextMatchId) {
          case (?nextMatchId) {
            Debug.print("Next match ID is not null: " # Nat.toText(nextMatchId));

            let nextMatchOpt = Array.find<Match>(matches, func(m : Match) : Bool { m.id == nextMatchId and m.tournamentId == tournamentId });
            switch (nextMatchOpt) {
              case (?nextMatch) {
                Debug.print("Next match found with ID: " # Nat.toText(nextMatchId));

                var updatedParticipants = Buffer.Buffer<Principal>(2);
                var replaced = false;

                for (p in nextMatch.participants.vals()) {
                  if (p == Principal.fromText("2vxsx-fae") and not replaced) {
                    updatedParticipants.add(winner);
                    replaced := true;
                  } else {
                    updatedParticipants.add(p);
                  };
                };

                Debug.print("Before update: " # participantsToString(nextMatch.participants));
                Debug.print("After update: " # participantsToString(Buffer.toArray(updatedParticipants)));

                let updatedNextMatch = {
                  id = nextMatch.id;
                  tournamentId = nextMatch.tournamentId;
                  participants = Buffer.toArray(updatedParticipants);
                  result = nextMatch.result;
                  status = nextMatch.status;
                  nextMatchId = nextMatch.nextMatchId;
                };

                // Update the next match in the matches array using Array.map
                matches := Array.map<Match, Match>(
                  matches,
                  func(m : Match) : Match {
                    if (m.id == nextMatchId and m.tournamentId == tournamentId) {
                      updatedNextMatch;
                    } else {
                      m;
                    };
                  },
                );
                Debug.print("Updated match in the matches map with ID: " # Nat.toText(nextMatchId));
              };
              case null {
                Debug.print("Error: Next match not found with ID: " # Nat.toText(nextMatchId));
              };
            };
          };
          case null {
            Debug.print("Next match ID is null for match ID: " # Nat.toText(matchId));
          };
        };
      };
      case null {
        Debug.print("Match not found for ID: " # Nat.toText(matchId));
      };
    };

    // Log the updated state of the matches
    for (i in Iter.range(0, matches.size() - 1)) {
      let match = matches[i];
      Debug.print("Updated Match: " # matchToString(match));
    };
  };

  private func matchToString(match : Match) : Text {
    return "Match ID: " # Nat.toText(match.id) # ", Participants: " # participantsToString(match.participants) # ", Result: " # (switch (match.result) { case (?res) { "Winner: " # Principal.toText(res.winner) # ", Score: " # res.score }; case null { "pending" } }) # ", Next Match ID: " # (switch (match.nextMatchId) { case (?nextId) { Nat.toText(nextId) }; case null { "none" } });
  };

  private func participantsToString(participants : [Principal]) : Text {
    var text = "";
    var first = true;
    for (participant in participants.vals()) {
      if (not first) {
        text #= ", ";
      };
      first := false;
      text #= Principal.toText(participant);
    };
    return text;
  };

  public shared func updateBracket(tournamentId : Nat) : async Bool {
    if (tournamentId >= tournaments.size()) {
      // Debug.print("Tournament does not exist.");
      return false;
    };

    var tournament = tournaments[tournamentId];
    let participants = tournament.participants;

    // Close registration if not already closed
    if (not tournament.bracketCreated) {
      let updatedTournament = {
        id = tournament.id;
        name = tournament.name;
        startDate = tournament.startDate;
        prizePool = tournament.prizePool;
        expirationDate = tournament.expirationDate;
        participants = tournament.participants;
        registeredParticipants = tournament.registeredParticipants;
        isActive = false;
        bracketCreated = true;
        matchCounter = tournament.matchCounter;
      };

      tournaments := Array.tabulate(
        tournaments.size(),
        func(i : Nat) : Tournament {
          if (i == tournamentId) {
            updatedTournament;
          } else {
            tournaments[i];
          };
        },
      );
    };

    // Obtain a fresh blob of entropy
    let entropy = await Random.blob();
    let random = Random.Finite(entropy);

    // Calculate total participants including byes
    var totalParticipants = 1;
    while (totalParticipants < participants.size()) {
      totalParticipants *= 2;
    };

    let byesCount = Nat.sub(totalParticipants, participants.size());
    var allParticipants = Buffer.Buffer<Principal>(totalParticipants);
    for (p in participants.vals()) {
      allParticipants.add(p);
    };
    for (i in Iter.range(0, byesCount - 1)) {
      allParticipants.add(Principal.fromText("aaaaa-aa"));
    };

    // Shuffle all participants and byes together
    var shuffledParticipants = Array.thaw<Principal>(Buffer.toArray(allParticipants));
    var i = shuffledParticipants.size();
    while (i > 1) {
      i -= 1;
      let j = switch (random.range(32)) {
        case (?value) { value % (i + 1) };
        case null { i };
      };
      let temp = shuffledParticipants[i];
      shuffledParticipants[i] := shuffledParticipants[j];
      shuffledParticipants[j] := temp;
    };

    Debug.print("Total participants after adjustment: " # Nat.toText(totalParticipants));

    // Store the total participants count for round 1
    let totalParticipantsRound1 = totalParticipants;

    // Create initial round matches with nextMatchId
    let roundMatches = Buffer.Buffer<Match>(0);
    var matchId = tournament.matchCounter;
    var nextMatchIdBase = totalParticipants / 2;
    for (i in Iter.range(0, totalParticipants / 2 - 1)) {
      let p1 = shuffledParticipants[i * 2];
      let p2 = shuffledParticipants[i * 2 + 1];
      let currentNextMatchId = ?(nextMatchIdBase + (i / 2));
      roundMatches.add({
        id = matchId;
        tournamentId = tournamentId;
        participants = [p1, p2];
        result = null;
        status = "scheduled";
        nextMatchId = currentNextMatchId;
      });
      Debug.print("Created match: " # Nat.toText(matchId) # " with participants: " # Principal.toText(p1) # " vs " # Principal.toText(p2) # " nextMatchId: " # (switch (currentNextMatchId) { case (?id) { Nat.toText(id) }; case null { "none" } }));
      matchId += 1;
    };
    nextMatchIdBase /= 2;

    // Update matchCounter in the tournament
    let updatedTournament = {
      id = tournament.id;
      name = tournament.name;
      startDate = tournament.startDate;
      prizePool = tournament.prizePool;
      expirationDate = tournament.expirationDate;
      participants = tournament.participants;
      registeredParticipants = tournament.registeredParticipants;
      isActive = tournament.isActive;
      bracketCreated = tournament.bracketCreated;
      matchCounter = matchId // Update matchCounter
    };

    tournaments := Array.tabulate(
      tournaments.size(),
      func(i : Nat) : Tournament {
        if (i == tournamentId) {
          updatedTournament;
        } else {
          tournaments[i];
        };
      },
    );

    // Function to recursively create matches for all rounds
    func createAllRounds(totalRounds : Nat, currentRound : Nat, matchId : Nat) : Buffer.Buffer<Match> {
      let newMatches = Buffer.Buffer<Match>(0);
      if (currentRound >= totalRounds) {
        return newMatches;
      };

      let numMatches = (totalParticipantsRound1 / (2 ** (currentRound + 1)));
      for (i in Iter.range(0, numMatches - 1)) {
        // Calculate next match ID correctly
        let nextMatchIdOpt = if (currentRound + 1 == totalRounds) {
          null;
        } else {
          ?(matchId + (i / 2) + numMatches);
        };

        newMatches.add({
          id = matchId + i;
          tournamentId = tournamentId;
          participants = [Principal.fromText("2vxsx-fae"), Principal.fromText("2vxsx-fae")];
          result = null;
          status = "scheduled";
          nextMatchId = nextMatchIdOpt;
        });
        Debug.print("Created next round match: " # Nat.toText(matchId + i) # " with nextMatchId: " # (switch (nextMatchIdOpt) { case (?id) { Nat.toText(id) }; case null { "none" } }));
      };

      // Recursively create next round matches
      let nextRoundMatches = createAllRounds(totalRounds, currentRound + 1, matchId + numMatches);
      for (match in nextRoundMatches.vals()) {
        newMatches.add(match);
      };

      return newMatches;
    };

    let totalRounds = log2(totalParticipantsRound1);
    Debug.print("Total rounds: " # Nat.toText(totalRounds));
    let subsequentRounds = createAllRounds(totalRounds, 1, matchId);

    // Update the stable variable matches
    var updatedMatches = Buffer.Buffer<Match>(matches.size() + roundMatches.size() + subsequentRounds.size());
    for (match in matches.vals()) {
      updatedMatches.add(match);
    };
    for (newMatch in roundMatches.vals()) {
      updatedMatches.add(newMatch);
    };
    for (subsequentMatch in subsequentRounds.vals()) {
      updatedMatches.add(subsequentMatch);
    };
    matches := Buffer.toArray(updatedMatches);

    // Manually create text representation for matches
    var matchesText = "";
    var firstMatch = true;
    for (match in matches.vals()) {
      if (not firstMatch) {
        matchesText #= ", ";
      };
      firstMatch := false;
      let nextMatchIdText = switch (match.nextMatchId) {
        case (?id) { Nat.toText(id) };
        case null { "none" };
      };
      matchesText #= "Match ID: " # Nat.toText(match.id) # " nextMatchId: " # nextMatchIdText;
    };

    Debug.print("Bracket created with matches: " # matchesText);

    return true;
  };

  public query func getActiveTournaments() : async [Tournament] {
    return Array.filter<Tournament>(tournaments, func(t : Tournament) : Bool { t.isActive });
  };

  public query func getInactiveTournaments() : async [Tournament] {
    return Array.filter<Tournament>(tournaments, func(t : Tournament) : Bool { not t.isActive });
  };

  public query func getAllTournaments() : async [Tournament] {
    return tournaments;
  };

  public query func getTournamentBracket(tournamentId : Nat) : async {
    matches : [Match];
  } {
    return {
      matches = Array.filter<Match>(matches, func(m : Match) : Bool { m.tournamentId == tournamentId });
    };
  };

  public shared func deleteAllTournaments() : async Bool {
    tournaments := [];
    matches := [];
    return true;
  };
  // #endregion

  //#region |ICRC7|

  // Hardcoded values for collectionOwner and init
  private let icrc7_CollectionOwner : TypesICRC7.Account = {
    owner = canister_ID;
    subaccount = null;
  };

  private let icrc7_InitArgs : TypesICRC7.CollectionInitArgs = {
    name = "Cosmicrafts NFTs";
    symbol = "Cosmicrafts";
    royalties = null;
    royaltyRecipient = null;
    description = ?"Trade, upgrade, and share with friends to unleash mayhem in the metaverse! Collect powerful spaceships, unlock legendary loot in mysterious metacubes, and craft your own style with unique avatars and rare items. Forge your cosmic empire and become a legend among the stars.";
    image = null;
    supplyCap = null; // No cap
  };

  stable var lastMintedId : Nat = 0;

  private stable var owner : TypesICRC7.Account = icrc7_CollectionOwner;

  private stable var name : Text = icrc7_InitArgs.name;
  private stable var symbol : Text = icrc7_InitArgs.symbol;
  private stable var royalties : ?Nat16 = icrc7_InitArgs.royalties;
  private stable var royaltyRecipient : ?TypesICRC7.Account = icrc7_InitArgs.royaltyRecipient;
  private stable var description : ?Text = icrc7_InitArgs.description;
  private stable var image : ?Blob = icrc7_InitArgs.image;
  private stable var supplyCap : ?Nat = icrc7_InitArgs.supplyCap;
  private stable var totalSupply : Nat = 0;
  private stable var transferSequentialIndex : Nat = 0;
  private stable var approvalSequentialIndex : Nat = 0;
  private stable var transactionSequentialIndex : Nat = 0;

  private var PERMITTED_DRIFT : Nat64 = 2 * 60 * 1_000_000_000; // 2 minutes in nanoseconds
  private var TX_WINDOW : Nat64 = 24 * 60 * 60 * 1_000_000_000; // 24 hours in nanoseconds

  private stable var tokens : Trie<TypesICRC7.TokenId, TypesICRC7.TokenMetadata> = Trie.empty();
  //owner Trie: use of Text insted of Account to improve performanances in lookup
  private stable var owners : Trie<Text, [TypesICRC7.TokenId]> = Trie.empty(); //fast lookup
  //balances Trie: use of Text insted of Account to improve performanances in lookup (could also retrieve this from owners[account].size())
  private stable var balances : Trie<Text, Nat> = Trie.empty(); //fast lookup

  //approvals by account Trie
  private stable var tokenApprovals : Trie<TypesICRC7.TokenId, [TypesICRC7.TokenApproval]> = Trie.empty();
  //approvals by operator Trie: use of Text insted of Account to improve performanances in lookup
  private stable var operatorApprovals : Trie<Text, [TypesICRC7.OperatorApproval]> = Trie.empty();

  //transactions Trie
  private stable var transactions : Trie<TypesICRC7.TransactionId, TypesICRC7.Transaction> = Trie.empty();
  //transactions by operator Trie: use of Text insted of Account to improve performanances in lookup
  private stable var transactionsByAccount : Trie<Text, [TypesICRC7.TransactionId]> = Trie.empty();

  // we do this to have shorter type names and thus better readibility
  // see https://internetcomputer.org/docs/current/motoko/main/base/Trie
  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;

  // we have to provide `put`, `get` and `remove` with
  // a record of type `Key<K> = { hash: Hash.Hash; key: K }`;
  // thus we define the following function that takes a value of type `K`
  // (in this case `Text`) and returns a `Key<K>` record.
  // see https://internetcomputer.org/docs/current/motoko/main/base/Trie
  private func _keyFromTokenId(t : TypesICRC7.TokenId) : Key<TypesICRC7.TokenId> {
    { hash = Utils._natHash(t); key = t };
  };
  private func _keyFromText(t : Text) : Key<Text> {
    { hash = Text.hash t; key = t };
  };
  private func _keyFromTransactionId(t : TypesICRC7.TransactionId) : Key<TypesICRC7.TransactionId> {
    { hash = Utils._natHash(t); key = t };
  };
  public shared query func icrc7_collection_metadata() : async TypesICRC7.CollectionMetadata {
    return {
      name = name;
      symbol = symbol;
      royalties = royalties;
      royaltyRecipient = royaltyRecipient;
      description = description;
      image = image;
      totalSupply = totalSupply;
      supplyCap = supplyCap;
    };
  };
  public shared query func icrc7_name() : async Text {
    return name;
  };
  public shared query func icrc7_symbol() : async Text {
    return symbol;
  };
  public shared query func icrc7_royalties() : async ?Nat16 {
    return royalties;
  };
  public shared query func icrc7_royalty_recipient() : async ?TypesICRC7.Account {
    return royaltyRecipient;
  };
  public shared query func icrc7_description() : async ?Text {
    return description;
  };
  public shared query func icrc7_image() : async ?Blob {
    return image;
  };
  public shared query func icrc7_total_supply() : async Nat {
    return totalSupply;
  };
  public shared query func icrc7_supply_cap() : async ?Nat {
    return supplyCap;
  };
  public shared query func icrc7_metadata(tokenId : TypesICRC7.TokenId) : async TypesICRC7.MetadataResult {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?_elem) {
        return #Ok(_elem.metadata);
      };
    };
  };
  public shared query func icrc7_owner_of(tokenId : TypesICRC7.TokenId) : async TypesICRC7.OwnerResult {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?_elem) {
        return #Ok(_elem.owner);
      };
    };
  };
  public shared query func icrc7_balance_of(account : TypesICRC7.Account) : async TypesICRC7.BalanceResult {
    let acceptedAccount : TypesICRC7.Account = _acceptAccount(account);
    let accountText : Text = ICRC7Utils.accountToText(acceptedAccount);
    let item = Trie.get(balances, _keyFromText accountText, Text.equal);
    switch (item) {
      case null {
        return #Ok(0);
      };
      case (?_elem) {
        return #Ok(_elem);
      };
    };
  };
  public shared query func icrc7_tokens_of(account : TypesICRC7.Account) : async TypesICRC7.TokensOfResult {
    let acceptedAccount : TypesICRC7.Account = _acceptAccount(account);
    let accountText : Text = ICRC7Utils.accountToText(acceptedAccount);
    let item = Trie.get(owners, _keyFromText accountText, Text.equal);
    switch (item) {
      case null {
        return #Ok([]);
      };
      case (?_elem) {
        return #Ok(_elem);
      };
    };
  };
  public shared ({ caller }) func icrc7_transfer(transferArgs : TypesICRC7.TransferArgs) : async TypesICRC7.TransferReceipt {
    let now = Nat64.fromIntWrap(Time.now());

    let callerSubaccount : TypesICRC7.Subaccount = switch (transferArgs.spender_subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };
    let acceptedCaller : TypesICRC7.Account = _acceptAccount({
      owner = caller;
      subaccount = ?callerSubaccount;
    });

    let acceptedFrom : TypesICRC7.Account = switch (transferArgs.from) {
      case null acceptedCaller;
      case (?_elem) _acceptAccount(_elem);
    };

    let acceptedTo : TypesICRC7.Account = _acceptAccount(transferArgs.to);

    if (transferArgs.created_at_time != null) {
      if (Nat64.less(Utils.nullishCoalescing<Nat64>(transferArgs.created_at_time, 0), now - TX_WINDOW - PERMITTED_DRIFT)) {
        return #Err(#TooOld());
      };

      if (Nat64.greater(Utils.nullishCoalescing<Nat64>(transferArgs.created_at_time, 0), now + PERMITTED_DRIFT)) {
        return #Err(#CreatedInFuture({ ledger_time = now }));
      };

    };

    if (transferArgs.token_ids.size() == 0) {
      return #Err(#GenericError({ error_code = _transferErrorCodeToCode(#EmptyTokenIds); message = _transferErrorCodeToText(#EmptyTokenIds) }));
    };

    //no duplicates in token ids are allowed
    let duplicatesCheckHashMap = HashMap.HashMap<TypesICRC7.TokenId, Bool>(5, Nat.equal, Utils._natHash);
    for (tokenId in transferArgs.token_ids.vals()) {
      let duplicateCheck = duplicatesCheckHashMap.get(tokenId);
      if (duplicateCheck != null) {
        return #Err(#GenericError({ error_code = _transferErrorCodeToCode(#DuplicateInTokenIds); message = _transferErrorCodeToText(#DuplicateInTokenIds) }));
      };
    };

    //by default is_atomic is true
    let isAtomic : Bool = Utils.nullishCoalescing<Bool>(transferArgs.is_atomic, true);

    //? should be added here deduplication?

    if (isAtomic) {
      let errors = Buffer.Buffer<TypesICRC7.TransferError>(0); // Creates a new Buffer
      for (tokenId in transferArgs.token_ids.vals()) {
        let transferResult = _singleTransfer(?acceptedCaller, acceptedFrom, acceptedTo, tokenId, true, now);
        switch (transferResult) {
          case null {};
          case (?_elem) errors.add(_elem);
        };
      };

      //todo errors should be re-processed to aggregate tokenIds in order to have them in a single token_ids array (Unanthorized standard specifications)
      if (errors.size() > 0) {
        return #Err(errors.get(0));
      };
    };

    let transferredTokenIds = Buffer.Buffer<TypesICRC7.TokenId>(0); //Creates a new Buffer of transferred tokens
    let errors = Buffer.Buffer<TypesICRC7.TransferError>(0); // Creates a new Buffer
    for (tokenId in transferArgs.token_ids.vals()) {
      let transferResult = _singleTransfer(?acceptedCaller, acceptedFrom, acceptedTo, tokenId, false, now);
      switch (transferResult) {
        case null transferredTokenIds.add(tokenId);
        case (?_elem) errors.add(_elem);
      };
    };

    if (isAtomic) {
      assert (errors.size() == 0);
    };

    //? it's not clear if return the Err or Ok
    if (errors.size() > 0) {
      return #Err(errors.get(0));
    };

    let transferId : Nat = transferSequentialIndex;
    _incrementTransferIndex();

    let _transaction : TypesICRC7.Transaction = _addTransaction(#icrc7_transfer, now, ?Buffer.toArray(transferredTokenIds), ?acceptedTo, ?acceptedFrom, ?acceptedCaller, transferArgs.memo, transferArgs.created_at_time, null);

    return #Ok(transferId);
  };
  public shared ({ caller }) func icrc7_approve(approvalArgs : TypesICRC7.ApprovalArgs) : async TypesICRC7.ApprovalReceipt {
    let now = Nat64.fromIntWrap(Time.now());

    let callerSubaccount : TypesICRC7.Subaccount = switch (approvalArgs.from_subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };
    let acceptedFrom : TypesICRC7.Account = _acceptAccount({
      owner = caller;
      subaccount = ?callerSubaccount;
    });

    let acceptedSpender : TypesICRC7.Account = _acceptAccount(approvalArgs.spender);

    if (ICRC7Utils.compareAccounts(acceptedFrom, acceptedSpender) == #equal) {
      return #Err(#GenericError({ error_code = _approveErrorCodeToCode(#SelfApproval); message = _approveErrorCodeToText(#SelfApproval) }));
    };

    if (approvalArgs.created_at_time != null) {
      if (Nat64.less(ICRC7Utils.nullishCoalescing<Nat64>(approvalArgs.created_at_time, 0), now - TX_WINDOW - PERMITTED_DRIFT)) {
        return #Err(#TooOld());
      };
    };

    let tokenIds : [TypesICRC7.TokenId] = switch (approvalArgs.token_ids) {
      case null [];
      case (?_elem) _elem;
    };

    let unauthorizedTokenIds = Buffer.Buffer<TypesICRC7.ApprovalId>(0);

    for (tokenId in tokenIds.vals()) {
      if (_exists(tokenId) == false) {
        unauthorizedTokenIds.add(tokenId);
      } else if (_isOwner(acceptedFrom, tokenId) == false) {
        //check if the from is owner of approved token
        unauthorizedTokenIds.add(tokenId);
      };
    };

    if (unauthorizedTokenIds.size() > 0) {
      return #Err(#Unauthorized({ token_ids = Buffer.toArray(unauthorizedTokenIds) }));
    };

    let approvalId : TypesICRC7.ApprovalId = _createApproval(acceptedFrom, acceptedSpender, tokenIds, approvalArgs.expires_at, approvalArgs.memo, approvalArgs.created_at_time);

    let _transaction : TypesICRC7.Transaction = _addTransaction(#icrc7_approve, now, approvalArgs.token_ids, null, ?acceptedFrom, ?acceptedSpender, approvalArgs.memo, approvalArgs.created_at_time, approvalArgs.expires_at);

    return #Ok(approvalId);
  };
  public shared query func icrc7_supported_standards() : async [TypesICRC7.SupportedStandard] {
    return [{
      name = "ICRC-7";
      url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-7";
    }];
  };
  public shared query func get_collection_owner() : async TypesICRC7.Account {
    return owner;
  };
  public func icrc7_get_transactions(getTransactionsArgs : TypesICRC7.GetTransactionsArgs) : async TypesICRC7.GetTransactionsResult {
    let result : TypesICRC7.GetTransactionsResult = switch (getTransactionsArgs.account) {
      case null {
        let allTransactions : [TypesICRC7.Transaction] = Trie.toArray<TypesICRC7.TransactionId, TypesICRC7.Transaction, TypesICRC7.Transaction>(
          transactions,
          func(k, v) = v,
        );

        let checkedOffset = Nat.min(Array.size(allTransactions), getTransactionsArgs.offset);
        let length = Nat.min(getTransactionsArgs.limit, Array.size(allTransactions) - checkedOffset);
        let subArray : [TypesICRC7.Transaction] = Array.subArray<TypesICRC7.Transaction>(allTransactions, checkedOffset, length);
        {
          total = Array.size(allTransactions);
          transactions = subArray;
        };
      };
      case (?_elem) {
        let acceptedAccount : TypesICRC7.Account = _acceptAccount(_elem);
        let accountText : Text = ICRC7Utils.accountToText(acceptedAccount);
        let accountTransactions : [TypesICRC7.TransactionId] = ICRC7Utils.nullishCoalescing<[TypesICRC7.TransactionId]>(Trie.get(transactionsByAccount, _keyFromText accountText, Text.equal), []);
        let reversedAccountTransactions : [TypesICRC7.TransactionId] = Array.reverse(accountTransactions);

        let checkedOffset = Nat.min(Array.size(reversedAccountTransactions), getTransactionsArgs.offset);
        let length = Nat.min(getTransactionsArgs.limit, Array.size(reversedAccountTransactions) - checkedOffset);
        let subArray : [TypesICRC7.TransactionId] = Array.subArray<TypesICRC7.TransactionId>(reversedAccountTransactions, checkedOffset, length);

        let returnedTransactions = Buffer.Buffer<TypesICRC7.Transaction>(0);

        for (transactionId in subArray.vals()) {
          let transaction = Trie.get(transactions, _keyFromTransactionId transactionId, Nat.equal);
          switch (transaction) {
            case null {};
            case (?_elem) returnedTransactions.add(_elem);
          };
        };

        {
          total = Array.size(reversedAccountTransactions);
          transactions = Buffer.toArray(returnedTransactions);
        };
      };
    };
    return result;
  };
  private func _addTokenToOwners(account : TypesICRC7.Account, tokenId : TypesICRC7.TokenId) {
    //get Textual rapresentation of the Account
    let textAccount : Text = ICRC7Utils.accountToText(account);

    //find the tokens owned by an account, in order to add the new one
    let newOwners = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenId]>(Trie.get(owners, _keyFromText textAccount, Text.equal), []);

    //add the token id
    owners := Trie.put(owners, _keyFromText textAccount, Text.equal, ICRC7Utils.pushIntoArray<TypesICRC7.TokenId>(tokenId, newOwners)).0;
  };
  private func _removeTokenFromOwners(account : TypesICRC7.Account, tokenId : TypesICRC7.TokenId) {
    //get Textual rapresentation of the Account
    let textAccount : Text = ICRC7Utils.accountToText(account);

    //find the tokens owned by an account, in order to add the new one
    let newOwners = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenId]>(Trie.get(owners, _keyFromText textAccount, Text.equal), []);

    let updated : [TypesICRC7.TokenId] = Array.filter<TypesICRC7.TokenId>(newOwners, func x = x != tokenId);

    //add the token id
    owners := Trie.put(owners, _keyFromText textAccount, Text.equal, updated).0;
  };
  private func _incrementBalance(account : TypesICRC7.Account) {
    //get Textual rapresentation of the Account
    let textAccount : Text = ICRC7Utils.accountToText(account);

    //find the balance of an account, in order to increment
    let balanceResult = Trie.get(balances, _keyFromText textAccount, Text.equal);

    let actualBalance : Nat = switch (balanceResult) {
      case null 0;
      case (?_elem) _elem;
    };

    //update the balance
    balances := Trie.put(balances, _keyFromText textAccount, Text.equal, actualBalance + 1).0;
  };
  private func _decrementBalance(account : TypesICRC7.Account) {
    // Get textual representation of the account
    let textAccount : Text = ICRC7Utils.accountToText(account);

    // Find the balance of an account, in order to decrement
    let balanceResult = Trie.get(balances, _keyFromText textAccount, Text.equal);

    switch balanceResult {
      case null { /* Balance not found, nothing to decrement */ };
      case (?actualBalance) {
        if (Nat.greater(actualBalance, 0)) {
          balances := Trie.put(balances, _keyFromText textAccount, Text.equal, Nat.sub(actualBalance, 1)).0;
        };
      };
    };
  };
  private func _incrementTotalSupply(quantity : Nat) {
    totalSupply := totalSupply + quantity;
  };
  private func _singleTransfer(caller : ?TypesICRC7.Account, from : TypesICRC7.Account, to : TypesICRC7.Account, tokenId : TypesICRC7.TokenId, dryRun : Bool, now : Nat64) : ?TypesICRC7.TransferError {
    //check if token exists
    if (_exists(tokenId) == false) {
      return ? #Unauthorized({
        token_ids = [tokenId];
      });
    };

    //check if caller is owner or approved to transferred token
    switch (caller) {
      case null {};
      case (?_elem) {
        if (_isApprovedOrOwner(_elem, tokenId, now) == false) {
          return ? #Unauthorized({
            token_ids = [tokenId];
          });
        };
      };
    };

    //check if the from is owner of transferred token
    if (_isOwner(from, tokenId) == false) {
      return ? #Unauthorized({
        token_ids = [tokenId];
      });
    };

    if (dryRun == false) {
      _deleteAllTokenApprovals(tokenId);
      _removeTokenFromOwners(from, tokenId);
      _decrementBalance(from);

      //change the token owner
      _updateToken(tokenId, ?to, null);

      _addTokenToOwners(to, tokenId);
      _incrementBalance(to);
    };

    return null;
  };
  private func _updateToken(tokenId : TypesICRC7.TokenId, newOwner : ?TypesICRC7.Account, newMetadata : ?TypesICRC7.Metadata) {
    let item = Trie.get(tokens, _keyFromTokenId(tokenId), Nat.equal);

    switch (item) {
      case null {
        return;
      };
      case (?_elem) {
        // Update owner
        let newToken : TypesICRC7.TokenMetadata = {
          tokenId = _elem.tokenId;
          owner = ICRC7Utils.nullishCoalescing<TypesICRC7.Account>(newOwner, _elem.owner);
          metadata = ICRC7Utils.nullishCoalescing<TypesICRC7.Metadata>(newMetadata, _elem.metadata);
        };

        // Update the token metadata
        tokens := Trie.put(tokens, _keyFromTokenId(tokenId), Nat.equal, newToken).0;
        return;
      };
    };
  };
  private func _isApprovedOrOwner(spender : TypesICRC7.Account, tokenId : TypesICRC7.TokenId, now : Nat64) : Bool {
    return _isOwner(spender, tokenId) or _isApproved(spender, tokenId, now);
  };
  private func _isOwner(spender : TypesICRC7.Account, tokenId : TypesICRC7.TokenId) : Bool {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return false;
      };
      case (?_elem) {
        return ICRC7Utils.compareAccounts(spender, _elem.owner) == #equal;
      };
    };
  };
  private func _isApproved(spender : TypesICRC7.Account, tokenId : TypesICRC7.TokenId, now : Nat64) : Bool {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);

    switch (item) {
      case null {
        return false;
      };
      case (?_elem) {
        let ownerToText : Text = ICRC7Utils.accountToText(_elem.owner);
        let approvalsByThisOperator : [TypesICRC7.OperatorApproval] = ICRC7Utils.nullishCoalescing<[TypesICRC7.OperatorApproval]>(Trie.get(operatorApprovals, _keyFromText ownerToText, Text.equal), []);

        let approvalForThisSpender = Array.find<TypesICRC7.OperatorApproval>(approvalsByThisOperator, func x = ICRC7Utils.compareAccounts(spender, x.spender) == #equal and (x.expires_at == null or Nat64.greater(ICRC7Utils.nullishCoalescing<Nat64>(x.expires_at, 0), now)));

        switch (approvalForThisSpender) {
          case (?_foundOperatorApproval) return true;
          case null {
            let approvalsForThisToken : [TypesICRC7.TokenApproval] = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenApproval]>(Trie.get(tokenApprovals, _keyFromTokenId tokenId, Nat.equal), []);
            let approvalForThisToken = Array.find<TypesICRC7.TokenApproval>(approvalsForThisToken, func x = ICRC7Utils.compareAccounts(spender, x.spender) == #equal and (x.expires_at == null or Nat64.greater(ICRC7Utils.nullishCoalescing<Nat64>(x.expires_at, 0), now)));
            switch (approvalForThisToken) {
              case (?_foundTokenApproval) return true;
              case null return false;
            };

          };
        };

        return false;
      };
    };
  };
  private func _exists(tokenId : TypesICRC7.TokenId) : Bool {
    let tokensResult = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (tokensResult) {
      case null return false;
      case (?_elem) return true;
    };
  };
  private func _incrementTransferIndex() {
    transferSequentialIndex := transferSequentialIndex + 1;
  };
  private func _getDefaultSubaccount() : Blob {
    return Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
  };
  private func _acceptAccount(account : TypesICRC7.Account) : TypesICRC7.Account {
    let effectiveSubaccount : Blob = switch (account.subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };

    return {
      owner = account.owner;
      subaccount = ?effectiveSubaccount;
    };
  };
  private func _transferErrorCodeToCode(d : TypesICRC7.TransferErrorCode) : Nat {
    switch d {
      case (#EmptyTokenIds) 0;
      case (#DuplicateInTokenIds) 1;
    };
  };
  private func _transferErrorCodeToText(d : TypesICRC7.TransferErrorCode) : Text {
    switch d {
      case (#EmptyTokenIds) "Empty Token Ids";
      case (#DuplicateInTokenIds) "Duplicates in Token Ids array";
    };
  };
  private func _approveErrorCodeToCode(d : TypesICRC7.ApproveErrorCode) : Nat {
    switch d {
      case (#SelfApproval) 0;
    };
  };
  private func _approveErrorCodeToText(d : TypesICRC7.ApproveErrorCode) : Text {
    switch d {
      case (#SelfApproval) "No Self Approvals";
    };
  };
  private func _createApproval(from : TypesICRC7.Account, spender : TypesICRC7.Account, tokenIds : [TypesICRC7.TokenId], expiresAt : ?Nat64, memo : ?Blob, createdAtTime : ?Nat64) : TypesICRC7.ApprovalId {

    // Handle approvals
    if (tokenIds.size() == 0) {
      //get Textual rapresentation of the Account
      let fromTextAccount : Text = ICRC7Utils.accountToText(from);
      let approvalsByThisOperator : [TypesICRC7.OperatorApproval] = ICRC7Utils.nullishCoalescing<[TypesICRC7.OperatorApproval]>(Trie.get(operatorApprovals, _keyFromText fromTextAccount, Text.equal), []);
      let newApproval : TypesICRC7.OperatorApproval = {
        spender = spender;
        memo = memo;
        expires_at = expiresAt;
        created_at_time = createdAtTime;
      };

      //add the updated approval
      operatorApprovals := Trie.put(operatorApprovals, _keyFromText fromTextAccount, Text.equal, ICRC7Utils.pushIntoArray<TypesICRC7.OperatorApproval>(newApproval, approvalsByThisOperator)).0;
    } else {
      for (tokenId in tokenIds.vals()) {
        let approvalsForThisToken : [TypesICRC7.TokenApproval] = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenApproval]>(Trie.get(tokenApprovals, _keyFromTokenId tokenId, Nat.equal), []);
        let newApproval : TypesICRC7.TokenApproval = {
          spender = spender;
          memo = memo;
          expires_at = expiresAt;
          created_at_time = createdAtTime;
        };
        //add the updated approval
        tokenApprovals := Trie.put(tokenApprovals, _keyFromTokenId tokenId, Nat.equal, ICRC7Utils.pushIntoArray<TypesICRC7.TokenApproval>(newApproval, approvalsForThisToken)).0;
      };
    };

    let approvalId : TypesICRC7.ApprovalId = approvalSequentialIndex;
    _incrementApprovalIndex();

    return approvalId;
  };
  private func _incrementApprovalIndex() {
    approvalSequentialIndex := approvalSequentialIndex + 1;
  };
  private func _deleteAllTokenApprovals(tokenId : TypesICRC7.TokenId) {
    tokenApprovals := Trie.remove(tokenApprovals, _keyFromTokenId tokenId, Nat.equal).0;
  };
  private func _addTransaction(kind : { #mint; #icrc7_transfer; #icrc7_approve; #upgrade }, timestamp : Nat64, tokenIds : ?[TypesICRC7.TokenId], to : ?TypesICRC7.Account, from : ?TypesICRC7.Account, spender : ?TypesICRC7.Account, memo : ?Blob, createdAtTime : ?Nat64, expiresAt : ?Nat64) : TypesICRC7.Transaction {
    let transactionId : TypesICRC7.TransactionId = transactionSequentialIndex;
    _incrementTransactionIndex();

    let acceptedTo = ICRC7Utils.nullishCoalescing<TypesICRC7.Account>(to, _acceptAccount({ owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount() }));
    let acceptedFrom = ICRC7Utils.nullishCoalescing<TypesICRC7.Account>(from, _acceptAccount({ owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount() }));
    let acceptedSpender = ICRC7Utils.nullishCoalescing<TypesICRC7.Account>(spender, _acceptAccount({ owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount() }));

    let transaction : TypesICRC7.Transaction = switch kind {
      case (#mint) {
        {
          kind = "mint";
          timestamp = timestamp;
          mint = ?{
            to = acceptedTo;
            token_ids = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenId]>(tokenIds, []);
          };
          icrc7_transfer = null;
          icrc7_approve = null;
          upgrade = null;
        };
      };
      case (#upgrade) {
        {
          kind = "upgrade";
          timestamp = timestamp;
          mint = null;
          icrc7_transfer = null;
          icrc7_approve = null;
          upgrade = null;
        };
      };
      case (#icrc7_transfer) {
        {
          kind = "icrc7_transfer";
          timestamp = timestamp;
          mint = null;
          icrc7_transfer = ?{
            from = acceptedFrom;
            to = acceptedTo;
            spender = ?acceptedSpender;
            token_ids = ICRC7Utils.nullishCoalescing<[TypesICRC7.TokenId]>(tokenIds, []);
            memo = memo;
            created_at_time = createdAtTime;
          };
          icrc7_approve = null;
          upgrade = null;
        };
      };
      case (#icrc7_approve) {
        {
          kind = "icrc7_approve";
          timestamp = timestamp;
          mint = null;
          icrc7_transfer = null;
          icrc7_approve = ?{
            from = acceptedFrom;
            spender = acceptedSpender;
            token_ids = tokenIds;
            expires_at = expiresAt;
            memo = memo;
            created_at_time = createdAtTime;
          };
          upgrade = null;
        };
      };
    };

    transactions := Trie.put(transactions, _keyFromTransactionId transactionId, Nat.equal, transaction).0;

    switch kind {
      case (#mint) {
        _addTransactionIdToAccount(transactionId, acceptedTo);
      };
      case (#upgrade) {
        _addTransactionIdToAccount(transactionId, acceptedTo);
      };
      case (#icrc7_transfer) {
        _addTransactionIdToAccount(transactionId, acceptedTo);
        if (from != null) {
          if (ICRC7Utils.compareAccounts(acceptedFrom, acceptedTo) != #equal) {
            _addTransactionIdToAccount(transactionId, acceptedFrom);
          };
        };
        if (spender != null) {
          if (ICRC7Utils.compareAccounts(acceptedSpender, acceptedTo) != #equal and ICRC7Utils.compareAccounts(acceptedSpender, acceptedFrom) != #equal) {
            _addTransactionIdToAccount(transactionId, acceptedSpender);
          };
        };
      };
      case (#icrc7_approve) {
        _addTransactionIdToAccount(transactionId, acceptedFrom);
      };
    };

    return transaction;
  };
  private func _addTransactionIdToAccount(transactionId : TypesICRC7.TransactionId, account : TypesICRC7.Account) {
    let accountText : Text = ICRC7Utils.accountToText(_acceptAccount(account));
    let accountTransactions : [TypesICRC7.TransactionId] = ICRC7Utils.nullishCoalescing<[TypesICRC7.TransactionId]>(Trie.get(transactionsByAccount, _keyFromText accountText, Text.equal), []);
    transactionsByAccount := Trie.put(transactionsByAccount, _keyFromText accountText, Text.equal, ICRC7Utils.pushIntoArray<TypesICRC7.TransactionId>(transactionId, accountTransactions)).0;
  };
  private func _incrementTransactionIndex() {
    transactionSequentialIndex := transactionSequentialIndex + 1;
  };
  private func _burnToken(_caller : ?TypesICRC7.Account, from : TypesICRC7.Account, tokenId : TypesICRC7.TokenId, now : Nat64) : async ?TypesICRC7.TransferError {
    // Check if token exists
    if (_exists(tokenId) == false) {
      Debug.print("Token does not exist: " # Nat.toText(tokenId));
      return ? #Unauthorized({
        token_ids = [tokenId];
      });
    };

    // Check if the from is owner of the token
    if (_isOwner(from, tokenId) == false) {
      Debug.print("Unauthorized: Account " # Principal.toText(from.owner) # " is not the owner of token " # Nat.toText(tokenId));
      return ? #Unauthorized({
        token_ids = [tokenId];
      });
    };

    // Debug print for verification
    Debug.print("Burning token: " # Nat.toText(tokenId) # " from account: " # Principal.toText(from.owner));

    // Delete all token approvals
    _deleteAllTokenApprovals(tokenId);

    // Remove the token from the owner's list
    _removeTokenFromOwners(from, tokenId);

    // Decrement the owner's balance
    _decrementBalance(from);

    // Update the token ownership to the null principal
    let nullOwner : TypesICRC7.Account = {
      owner = NULL_PRINCIPAL;
      subaccount = null;
    };

    _updateToken(tokenId, ?nullOwner, null);

    // Record the burn transaction
    let transaction : TypesICRC7.Transaction = {
      kind = "burn";
      timestamp = now;
      mint = null;
      icrc7_transfer = null;
      icrc7_approve = null;
      upgrade = null;
      burn = ?{
        from = from;
        token_id = tokenId;
      };
    };
    transactions := Trie.put(transactions, _keyFromTransactionId(transactionSequentialIndex), Nat.equal, transaction).0;
    _incrementTransactionIndex();
    _addTransactionIdToAccount(transactionSequentialIndex, from);

    return null;
  };

  // Queries
  public query func getNFTs(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    let entries = Iter.toArray(Trie.iter(tokens));
    var resultBuffer = Buffer.Buffer<(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)>(0);

    for (entry in entries.vals()) {
      let key = entry.0;
      let value = entry.1;
      if (value.owner.owner == principal) {
        resultBuffer.add((key, value));
      };
    };
    return Buffer.toArray(resultBuffer);
  };
  public query func getChests(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    return _filterNFTsByCategory(principal, "Chest");
  };
  public query func getAvatars(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    return _filterNFTsByCategory(principal, "Avatar");
  };
  public query func getCharacters(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    return _filterNFTsByCategory(principal, "Character");
  };
  public query func getTrophies(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    return _filterNFTsByCategory(principal, "Trophy");
  };
  public query func getUnits(principal : Principal) : async [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    return _filterNFTsByCategory(principal, "Unit");
  };
  // Helper function to filter NFTs by a specified category
  private func _filterNFTsByCategory(caller : Principal, category : Text) : [(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)] {
    let entries = Iter.toArray(Trie.iter(tokens));
    var resultBuffer = Buffer.Buffer<(TypesICRC7.TokenId, TypesICRC7.TokenMetadata)>(0);

    for (entry in entries.vals()) {
      let key = entry.0;
      let value = entry.1;

      if (value.owner.owner == caller) {
        let match = switch (category) {
          case ("Avatar") switch (value.metadata.category) {
            case (#Avatar) true;
            case (_) false;
          };
          case ("Chest") switch (value.metadata.category) {
            case (#Chest) true;
            case (_) false;
          };
          case ("Trophy") switch (value.metadata.category) {
            case (#Trophy) true;
            case (_) false;
          };
          case ("Character") switch (value.metadata.category) {
            case (#Unit(unitCategory)) switch (unitCategory) {
              case (#Character) true;
              case (_) false;
            };
            case (_) false;
          };
          case ("Unit") switch (value.metadata.category) {
            case (#Unit(_)) true;
            case (_) false;
          };
          case (_) false;
        };

        if (match) {
          resultBuffer.add((key, value));
        };
      };
    };

    return Buffer.toArray(resultBuffer);
  };
  // #endregion

  //#region |GameNFTs|
  stable var _mintedCallers : [(Principal, Bool)] = [];
  var mintedCallersMap : HashMap.HashMap<Principal, Bool> = HashMap.fromIter(_mintedCallers.vals(), 0, Principal.equal, Principal.hash);

  public shared (msg) func upgradeNFT(nftID : TokenID) : async (Bool, Text) {
    // Perform ownership check
    let ownerof : TypesICRC7.OwnerResult = await icrc7_owner_of(nftID);
    let _owner : TypesICRC7.Account = switch (ownerof) {
      case (#Ok(owner)) owner;
      case (#Err(_)) return (false, "{\"success\":false, \"message\":\"NFT not found\"}");
    };

    if (Principal.notEqual(_owner.owner, msg.caller)) {
      return (false, "{\"success\":false, \"message\":\"You do not own this NFT.\"}");
    };

    // Retrieve metadata
    let metadataResult = await icrc7_metadata(nftID);
    let _nftMetadata : TypesICRC7.Metadata = switch (metadataResult) {
      case (#Ok(metadata)) metadata;
      case (#Err(_)) return (false, "{\"success\":false, \"message\":\"NFT metadata not found\"}");
    };

    // Calculate upgrade cost
    let nftLevel : Nat = switch (_nftMetadata.basic) {
      case null { 0 };
      case (?basic) { basic.level };
    };
    let upgradeCost = Utils.calculateCost(nftLevel);
    let fee = await icrc1_fee();

    // Create transaction arguments for the upgrade cost
    let _transactionsArgs = {
      amount : TypesICRC1.Balance = upgradeCost;
      created_at_time : ?Nat64 = ?Nat64.fromNat(Int.abs(Time.now()));
      fee = ?fee;
      from_subaccount : ?TypesICRC1.Subaccount = null;
      memo : ?Blob = null;
      to : TypesICRC1.Account = {
        owner = Principal.fromText("aaaaa-aa");
        subaccount = null;
      };
    };

    // Transfer the upgrade cost
    let transfer : TypesICRC1.TransferResult = await icrc1_transfer(_transactionsArgs);

    switch (transfer) {
      case (#Err(_e)) {
        return (false, "{\"success\":false, \"message\":\"Upgrade cost transfer failed\"}");
      };
      case (#Ok(_)) {
        // Prepare for upgrade
        var updatedMetadata = _nftMetadata;

        // Update basic metadata fields
        switch (updatedMetadata.basic) {
          case null {};
          case (?basic) {
            // If basic is not null, upgrade the existing values
            let newLevel = basic.level + 1;

            // Health upgrade
            let currentHealth : Float = Float.fromInt64(Int64.fromInt(basic.health)) / 100.0;
            let upgradedHealth : Float = currentHealth * 1.1 * 100.0;
            let newHealth = Int64.toNat64(Float.toInt64(upgradedHealth));

            // Damage upgrade
            let currentDamage : Float = Float.fromInt64(Int64.fromInt(basic.damage)) / 100.0;
            let upgradedDamage : Float = currentDamage * 1.1 * 100.0;
            let newDamage = Int64.toNat64(Float.toInt64(upgradedDamage));

            // Create a new BasicMetadata record with updated values
            let newBasic : TypesICRC7.BasicMetadata = {
              level = newLevel;
              health = Nat64.toNat(newHealth);
              damage = Nat64.toNat(newDamage);
            };

            // Reassign the updated metadata
            updatedMetadata := {
              category = updatedMetadata.category;
              general = updatedMetadata.general;
              basic = ?newBasic;
              skills = updatedMetadata.skills;
              skins = updatedMetadata.skins;
              soul = updatedMetadata.soul;
            };
          };
        };

        // Ensure the 'from' owner is not NULL_PRINCIPAL
        if (Principal.equal(_owner.owner, NULL_PRINCIPAL)) {
          return (false, "{\"success\":false, \"message\":\"Invalid recipient (NULL_PRINCIPAL)\"}");
        };

        // Ensure the token exists
        let alreadyExists = _exists(nftID);
        if (alreadyExists == false) {
          return (false, "{\"success\":false, \"message\":\"Token does not exist\"}");
        };

        let now = Nat64.fromIntWrap(Time.now());

        // Create the new token metadata
        let upgradedToken : TypesICRC7.TokenMetadata = {
          tokenId = nftID;
          owner = _owner;
          metadata = updatedMetadata;
        };

        // Update the token metadata
        tokens := Trie.put(tokens, _keyFromTokenId nftID, Nat.equal, upgradedToken).0;

        _addTokenToOwners(_owner, nftID);

        let _transaction : TypesICRC7.Transaction = _addTransaction(#upgrade, now, ?[nftID], ?_owner, null, null, null, null, null);
        let (_achievementResult, _achievementMessage) = await updateUpgradeNFTAchievement(msg.caller);
        // Return success with updated metadata
        return (true, "Upgrade successful. New Metadata: " # debug_show (updatedMetadata));
      };
    };
  };
  public shared ({ caller }) func mintNFT(mintArgs : TypesICRC7.MintArgs) : async TypesICRC7.MintReceipt {
    let now = Nat64.fromIntWrap(Time.now());
    let acceptedTo : TypesICRC7.Account = _acceptAccount(mintArgs.to);

    //todo add a more complex roles management
    if (Principal.notEqual(caller, owner.owner) and Principal.notEqual(caller, canister_ID)) {
      return #Err(#Unauthorized);
    };

    //check on supply cap overflow
    if (supplyCap != null) {
      let _supplyCap : Nat = ICRC7Utils.nullishCoalescing<Nat>(supplyCap, 0);
      if (totalSupply + 1 > _supplyCap) {
        return #Err(#SupplyCapOverflow);
      };
    };

    //cannot mint to zero principal
    if (Principal.equal(acceptedTo.owner, NULL_PRINCIPAL)) {
      return #Err(#InvalidRecipient);
    };

    //cannot mint an existing token id
    let alreadyExists = _exists(mintArgs.token_id);
    if (alreadyExists) {
      return #Err(#AlreadyExistTokenId);
    };

    //create the new token
    let newToken : TypesICRC7.TokenMetadata = {
      tokenId = mintArgs.token_id;
      owner = acceptedTo;
      metadata = mintArgs.metadata;
    };

    //update the token metadata
    let tokenId : TypesICRC7.TokenId = mintArgs.token_id;
    tokens := Trie.put(tokens, _keyFromTokenId tokenId, Nat.equal, newToken).0;

    _addTokenToOwners(acceptedTo, mintArgs.token_id);

    _incrementBalance(acceptedTo);

    _incrementTotalSupply(1);

    let _transaction : TypesICRC7.Transaction = _addTransaction(#mint, now, ?[mintArgs.token_id], ?acceptedTo, null, null, null, null, null);

    return #Ok(mintArgs.token_id);
  };
  public shared func mintDeck(id: Principal) : async (Bool, Text, [TypesICRC7.TokenId]) {
    let units = ICRC7Utils.initDeck(); // Initialize the deck with units
    var uuids = Buffer.Buffer<TypesICRC7.TokenId>(8);
    let initialTokenId = lastMintedId;

    for (i in Iter.range(0, 5)) {
      let (name, damage, hp, rarity, description, image) = units[i];
      let generalId = i + 1;
      let tokenId = initialTokenId + i + 1;

      // Create the general metadata
      let generalMetadata : TypesICRC7.GeneralMetadata = {
        rarity = ?rarity;
        faction = ? #Cosmicon;
        id = generalId;
        name = name;
        description = description;
        image = image;
      };

      // Initialize SoulMetadata with a birth date for all units and 25 XP for the "Devastator"
      let soulMetadata : TypesICRC7.SoulMetadata = if (name == "Devastator") {
        {
          birth = Time.now();
          combatExperience = 25;
          gamesPlayed = null;
          totalKills = null;
          totalDamageDealt = null;
        };
      } else {
        {
          birth = Time.now();
          combatExperience = 0;
          gamesPlayed = null;
          totalKills = null;
          totalDamageDealt = null;
        };
      };

      // Create the complete metadata record
      let spaceshipMetadata : TypesICRC7.Metadata = {
        category = #Unit(#Spaceship);
        general = generalMetadata;
        basic = ?{
          level = 1;
          health = hp;
          damage = damage;
        };
        skills = null;
        skins = null;
        soul = ?soulMetadata;
      };

      // Create the mint arguments
      let mintArgs : TypesICRC7.MintArgs = {
        to = { owner = id; subaccount = null };
        token_id = tokenId;
        metadata = spaceshipMetadata;
      };

      // Call the mintNFT function with the encapsulated mint arguments
      let mintResult = await mintNFT(mintArgs);

      // Handle the result of minting
      switch (mintResult) {
        case (#Ok(token_id)) {
          uuids.add(token_id);
          // Update minted game NFTs and log the transaction
          await updateMintedGameNFTs(id, token_id);
        };
        case (#Err(err)) Debug.print("Minting failed: " # debug_show (err));
      };
    };

    lastMintedId += 6;

    // Check if the caller has already minted a deck
    if (mintedCallersMap.get(id) != null) {
      return (false, "Deck mint failed: Caller has already minted a deck", []);
    };

    // Store the minted deck
    let storeSuccess = await storeDeck(id, Buffer.toArray(uuids)); // Pass the caller explicitly here
    if (not storeSuccess) {
      return (false, "Failed to store the minted deck", []);
    };

    mintedCallersMap.put(id, true);

    return (true, "Deck minted and stored successfully", Buffer.toArray(uuids));
  };


  private func mintUnit(templateId : Nat, owner : Principal) : async TypesICRC7.MintReceipt {
    let _now = Nat64.fromIntWrap(Time.now());
    let acceptedTo : TypesICRC7.Account = {
      owner = owner;
      subaccount = null;
    };

    // Fetch the NFTDetails from the predefined templates
    if (templateId < 1 or templateId > nftTemplates.size()) {
      return #Err(#Unauthorized);
    };

    let nftDetails = nftTemplates[templateId - 1]; // Adjust for 0-based indexing

    // Check if supply cap is exceeded
    if (supplyCap != null) {
      let _supplyCap : Nat = ICRC7Utils.nullishCoalescing<Nat>(supplyCap, 0);
      if (totalSupply + 1 > _supplyCap) {
        return #Err(#SupplyCapOverflow);
      };
    };

    // Check if the recipient is valid
    if (Principal.equal(acceptedTo.owner, NULL_PRINCIPAL)) {
      return #Err(#InvalidRecipient);
    };

    // Generate a new token ID
    let tokenId = lastMintedId + 1;

    // Check if the token ID already exists
    if (_exists(tokenId)) {
      return #Err(#AlreadyExistTokenId);
    };

    // Create the general metadata
    let generalMetadata : TypesICRC7.GeneralMetadata = {
      rarity = ?nftDetails.rarity;
      faction = ?nftDetails.faction;
      id = tokenId;
      name = nftDetails.name;
      description = nftDetails.description;
      image = nftDetails.image;
    };

    // Initialize SoulMetadata
    let soulMetadata : TypesICRC7.SoulMetadata = {
      birth = Time.now();
      combatExperience = nftDetails.combatExperience;
      gamesPlayed = null;
      totalKills = null;
      totalDamageDealt = null;
    };

    // Create the complete metadata record
    let unitMetadata : TypesICRC7.Metadata = {
      category = #Unit(nftDetails.unitType);
      general = generalMetadata;
      basic = ?{
        level = nftDetails.level;
        health = nftDetails.health;
        damage = nftDetails.damage;
      };
      skills = null;
      skins = null;
      soul = ?soulMetadata;
    };

    // Create the mint arguments
    let mintArgs : TypesICRC7.MintArgs = {
      to = acceptedTo;
      token_id = tokenId;
      metadata = unitMetadata;
    };

    // Call the mintNFT function with the encapsulated mint arguments
    let mintResult = await mintNFT(mintArgs);

    // Handle the result of minting
    switch (mintResult) {
      case (#Ok(token_id)) {
        lastMintedId += 1;
        return #Ok(token_id);
      };
      case (#Err(err)) return #Err(err);
    };
  };
  private let nftTemplates : [NFTDetails] = [
    {
      unitType = #Spaceship;
      name = "Gemini";
      description = "A glitch on the matrix";
      image = "imageURL";
      faction = #Celestial;
      rarity = 4;
      level = 1;
      health = 420;
      damage = 42;
      combatExperience = 0;
    },
    {
      unitType = #Spaceship;
      name = "Lazerhawk";
      description = "Wow a lazer wow";
      image = "imageURL";
      faction = #Celestial;
      rarity = 4;
      level = 1;
      health = 500;
      damage = 50;
      combatExperience = 10;
    },
    // Add more templates as needed
  ];
  // #endregion

  //#region |Chests|

  public func mintChest(PlayerId : Principal, rarity : Nat) : async (Bool, Text) {
    let uuid = lastMintedId + 1;
    lastMintedId := uuid;

    // Assuming `getChestMetadata` returns an object of type `Metadata`
    let chestMetadata = MetadataUtils.getChestMetadata(uuid, rarity);

    // Prepare the account to mint to
    let to : TypesICRC7.Account = { owner = PlayerId; subaccount = null };

    // Create the composite argument with the necessary fields
    let mintArgs = {
      metadata = chestMetadata;
      to = to;
      token_id = uuid;
    };

    // Call the `mintNFT` function with the composite argument
    let mintResult = await mintNFT(mintArgs);

    switch (mintResult) {
      case (#Ok(_transactionID)) {
        await updateMintedChests(PlayerId, uuid);
        return (true, "NFT minted. Transaction ID: " # Nat.toText(_transactionID));
      };
      case (#Err(_e)) {
        return (false, "NFT mint failed: " # Utils.errorToText(_e));
      };
    };
  };
  public shared ({ caller }) func openChest(chestID : Nat) : async (Bool, Text) {
    // Perform ownership check
    let ownerof : TypesICRC7.OwnerResult = await icrc7_owner_of(chestID);
    let _owner : TypesICRC7.Account = switch (ownerof) {
      case (#Ok(owner)) owner;
      case (#Err(_)) return (false, "{\"error\":true, \"message\":\"Chest not found\"}");
    };

    if (Principal.notEqual(_owner.owner, caller)) {
      return (false, "{\"error\":true, \"message\":\"Not the owner of the chest\"}");
    };

    // Get tokens to be minted and burn the chest
    let _chestArgs : TypesICRC7.OpenArgs = {
      from = _owner;
      token_id = chestID;
    };

    // Determine chest rarity based on metadata
    let metadataResult = await icrc7_metadata(chestID);
    let rarity = switch (metadataResult) {
      case (#Ok(metadata)) {
        switch (metadata.general.rarity) {
          case (?r) r;
          case null 1;
        };
      };
      case (#Err(_)) 1;
    };

    // Await the result of getTokensAmount
    let stardustAmount = Utils.getChestTokensAmount(rarity);

    // Burn the token (send to NULL address)
    let now = Nat64.fromIntWrap(Time.now());
    let burnResult = await _burnToken(null, _owner, chestID, now);

    switch (burnResult) {
      case null {
        // Prepare mint arguments
        let _stardustArgs : TypesICRC1.Mint = {
          to = { owner = caller; subaccount = null };
          amount = stardustAmount;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };

        // Mint stardust tokens
        let stardustMinted = await mint(_stardustArgs);

        // Handle stardust minting result
        let stardustResult = switch (stardustMinted) {
          case (#Ok(_tid)) {
            await updateMintedStardust(caller, stardustAmount);
            "{\"token\":\"Stardust\", \"transaction_id\": " # Nat.toText(_tid) # ", \"amount\": " # Nat.toText(stardustAmount) # "}";
          };
          case (#Err(_e)) Utils.handleMintError("Stardust", _e);
        };

        return (true, stardustResult);
      };
      case (?_elem) {
        return (false, Utils.handleChestError(_elem));
      };
    };
  };

  // #endregion

  //#region |ICRC1|

  private var init_args : TypesICRC1.TokenInitArgs = {
    name = "Stardust";
    symbol = "STDs";
    decimals = 8;
    logo = "logoGoesHere";
    fee = 1;
    max_supply = 10_000_000_000_000_000_000;
    initial_balances = [({ owner = canister_ID; subaccount = null }, 0)];
    minting_account = ?{ owner = canister_ID; subaccount = null };
    description = ?"Glittering particles born from the heart of dying stars. Stardust is the rarest and most precious substance in the Cosmicrafts universe, imbued with the power to create, enhance, and transform. Collect Stardust to unlock extraordinary crafts, upgrade your NFTs, and forge your own destiny among the stars.";
    advanced_settings = null;
    min_burn_amount = 0;
  };
  let icrc1_args : ICRC1.InitArgs = {
    init_args with minting_account = Option.get(
      init_args.minting_account,
      {
        owner = canister_ID;
        subaccount = null;
      },
    );
  };

  public query func getInitArgs() : async TypesICRC1.TokenInitArgs {
    return init_args;
  };
  stable let token = ICRC1.init(icrc1_args);
  public shared query func icrc1_name() : async Text {
    ICRC1.name(token);
  };
  public shared query func icrc1_symbol() : async Text {
    ICRC1.symbol(token);
  };
  public shared query func icrc1_decimals() : async Nat8 {
    ICRC1.decimals(token);
  };
  public shared query func icrc1_fee() : async ICRC1.Balance {
    ICRC1.fee(token);
  };
  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
    ICRC1.metadata(token);
  };
  public shared query func icrc1_total_supply() : async ICRC1.Balance {
    ICRC1.total_supply(token);
  };
  public shared query func icrc1_minting_account() : async ?ICRC1.Account {
    ?ICRC1.minting_account(token);
  };
  public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
    ICRC1.balance_of(token, args);
  };
  public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
    ICRC1.supported_standards(token);
  };
  public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
    await* ICRC1.transfer(token, args, caller);
  };
  public shared func icrc1_pay_for_transaction(args : ICRC1.TransferArgs, from : Principal) : async ICRC1.TransferResult {
    await* ICRC1.transfer(token, args, from);
  };
  public shared ({ caller }) func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
    await* ICRC1.mint(token, args, caller);
  };
  public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
    await* ICRC1.burn(token, args, caller);
  };
  public shared query func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
    ICRC1.get_transactions(token, req);
  };
  public shared func get_transaction(i : ICRC1.TxIndex) : async ?ICRC1.Transaction {
    await* ICRC1.get_transaction(token, i);
  };
  public shared func deposit_cycles() : async () {
    let amount = ExperimentalCycles.available();
    let accepted = ExperimentalCycles.accept<system>(amount);
    assert (accepted == amount);
  };
  // #endregion

  //#region |Logging|

  public type MintedStardust = {
    quantity : Nat;
  };

  public type MintedChest = {
    tokenIDs : [TokenID];
    quantity : Nat;
  };

  public type MintedGameNFT = {
    tokenIDs : [TokenID];
    quantity : Nat;
  };

  type LogEntry = {
    itemType : ItemType;
    user : Principal;
    amount : ?Nat;
    tokenID : ?TokenID;
    timestamp : Nat64;
  };

  type ItemType = {
    #Stardust;
    #GameNFTs;
    #Chest;
  };

  // Stable variables for storing minted token information
  stable var mintedStardust : [(Principal, MintedStardust)] = [];
  stable var mintedChests : [(Principal, MintedChest)] = [];
  stable var mintedGameNFTs : [(Principal, MintedGameNFT)] = [];
  stable var transactionLogs : [LogEntry] = [];

  // HashMaps for minted token information
  var mintedStardustMap : HashMap.HashMap<Principal, MintedStardust> = HashMap.HashMap<Principal, MintedStardust>(10, Principal.equal, Principal.hash);
  var mintedChestsMap : HashMap.HashMap<Principal, MintedChest> = HashMap.HashMap<Principal, MintedChest>(10, Principal.equal, Principal.hash);
  var mintedGameNFTsMap : HashMap.HashMap<Principal, MintedGameNFT> = HashMap.HashMap<Principal, MintedGameNFT>(10, Principal.equal, Principal.hash);

  // Function to update stable variables
  func updateStableVariables() {
    mintedStardust := Iter.toArray(mintedStardustMap.entries());
    mintedChests := Iter.toArray(mintedChestsMap.entries());
    mintedGameNFTs := Iter.toArray(mintedGameNFTsMap.entries());
  };

  // Function to update minted flux
  func updateMintedStardust(user : Principal, amount : Nat) : async () {
    let current = switch (mintedStardustMap.get(user)) {
      case (null) { { quantity = 0 } };
      case (?flux) { flux };
    };
    let updated = { quantity = current.quantity + amount };
    mintedStardustMap.put(user, updated);
    let timestamp : Nat64 = Nat64.fromIntWrap(Time.now());
    logTransaction(#Stardust, user, amount, timestamp);
    updateStableVariables();
  };

  // Function to update minted chests for a user
  func updateMintedChests(user : Principal, tokenID : TokenID) : async () {
    let current = switch (mintedChestsMap.get(user)) {
      case (null) { { tokenIDs = []; quantity = 0 } };
      case (?chests) { chests };
    };

    let tokenIDsBuffer = Buffer.Buffer<TokenID>(current.tokenIDs.size() + 1);
    for (id in current.tokenIDs.vals()) {
      tokenIDsBuffer.add(id);
    };
    tokenIDsBuffer.add(tokenID);

    let updated = {
      tokenIDs = Buffer.toArray(tokenIDsBuffer);
      quantity = current.quantity + 1;
    };
    mintedChestsMap.put(user, updated);

    let timestamp : Nat64 = Nat64.fromIntWrap(Time.now());
    logTransactionWithTokenID(#Chest, user, tokenID, timestamp);
    updateStableVariables();
  };

  // Function to update minted gameNFTs
  func updateMintedGameNFTs(user : Principal, tokenID : TokenID) : async () {
    let current = switch (mintedGameNFTsMap.get(user)) {
      case (null) { { tokenIDs = []; quantity = 0 } };
      case (?nfts) { nfts };
    };

    let tokenIDsBuffer = Buffer.Buffer<TokenID>(current.tokenIDs.size() + 1);
    for (id in current.tokenIDs.vals()) {
      tokenIDsBuffer.add(id);
    };
    tokenIDsBuffer.add(tokenID);

    let updated = {
      tokenIDs = Buffer.toArray(tokenIDsBuffer);
      quantity = current.quantity + 1;
    };
    mintedGameNFTsMap.put(user, updated);

    let timestamp : Nat64 = Nat64.fromIntWrap(Time.now());
    logTransactionWithTokenID(#GameNFTs, user, tokenID, timestamp);
    updateStableVariables();
  };

  // Function to add a log entry
  func addLogEntry(itemType : ItemType, user : Principal, amount : ?Nat, tokenID : ?TokenID, timestamp : Nat64) {
    let logEntry : LogEntry = {
      itemType = itemType;
      user = user;
      amount = amount;
      tokenID = tokenID;
      timestamp = timestamp;
    };

    let logsBuffer = Buffer.Buffer<LogEntry>(transactionLogs.size() + 1);
    for (log in transactionLogs.vals()) {
      logsBuffer.add(log);
    };
    logsBuffer.add(logEntry);

    transactionLogs := Buffer.toArray(logsBuffer);
  };

  // Function to log transactions with amount
  func logTransaction(itemType : ItemType, user : Principal, amount : Nat, timestamp : Nat64) {
    addLogEntry(itemType, user, ?amount, null, timestamp);
  };

  // Function to log transactions with tokenID
  func logTransactionWithTokenID(itemType : ItemType, user : Principal, tokenID : TokenID, timestamp : Nat64) {
    addLogEntry(itemType, user, null, ?tokenID, timestamp);
  };

  // Function to retrieve logs for a specific user and item type
  public query func getTransactionLogs(user : Principal, itemType : ItemType) : async [LogEntry] {
    return Array.filter<LogEntry>(
      transactionLogs,
      func(log : LogEntry) : Bool {
        log.user == user and log.itemType == itemType
      },
    );
  };

  public query func getMintedInfo(user : Principal) : async {
    stardust : Nat;
    chests : { quantity : Nat; tokenIDs : [TokenID] };
    gameNFTs : { quantity : Nat; tokenIDs : [TokenID] };
  } {
    let stardust = switch (mintedStardustMap.get(user)) {
      case (null) 0;
      case (?stardustData) stardustData.quantity;
    };

    let chests = switch (mintedChestsMap.get(user)) {
      case (null) ({ quantity = 0; tokenIDs = [] });
      case (?chestsData) chestsData;
    };

    let gameNFTs = switch (mintedGameNFTsMap.get(user)) {
      case (null) ({ quantity = 0; tokenIDs = [] });
      case (?gameNFTsData) gameNFTsData;
    };

    return {
      stardust = stardust;
      chests = chests;
      gameNFTs = gameNFTs;
    };
  };
  // #endregion

  //#region |Migrations|

  system func preupgrade() {
    // Save the state of the stable variables
    savedPlayerDecks := playerDecks;

    _referrals := Iter.toArray(referrals.entries());

    _generalUserProgress := Iter.toArray(generalUserProgress.entries());
    _missions := Iter.toArray(missions.entries());
    _activeMissions := Iter.toArray(activeMissions.entries());
    _claimedRewards := Iter.toArray(claimedRewards.entries());

    _individualAchievements := Iter.toArray(individualAchievements.entries());
    _achievements := Iter.toArray(achievements.entries());

    _userMissionProgress := Iter.toArray(userMissionProgress.entries());
    _userMissions := Iter.toArray(userMissions.entries());
    _userMissionCounters := Iter.toArray(userMissionCounters.entries());
    _userClaimedRewards := Iter.toArray(userClaimedRewards.entries());

    _basicStats := Iter.toArray(basicStats.entries());
    _playerGamesStats := Iter.toArray(playerGamesStats.entries());
    _onValidation := Iter.toArray(onValidation.entries());
    _countedMatches := Iter.toArray(countedMatches.entries());

    _searching := Iter.toArray(searching.entries());
    _playerStatus := Iter.toArray(playerStatus.entries());
    _inProgress := Iter.toArray(inProgress.entries());
    _finishedGames := Iter.toArray(finishedGames.entries());

    // Save the state of the achievement-related stable variables
    _achievementCategories := Iter.toArray(achievementCategories.entries());
    _achievements := Iter.toArray(achievements.entries());
    _individualAchievements := Iter.toArray(individualAchievements.entries());

    _userProgress := Iter.toArray(userProgress.entries());

    _claimedIndividualAchievementRewards := Iter.toArray(claimedIndividualAchievementRewards.entries());
    _claimedAchievementLineRewards := Iter.toArray(claimedAchievementLineRewards.entries());
    _claimedCategoryAchievementRewards := Iter.toArray(claimedCategoryAchievementRewards.entries());

    _userBasicInfo := Iter.toArray(userBasicInfo.entries());
    _userNetwork := Iter.toArray(userNetwork.entries());

  };

  system func postupgrade() {
    // Restore the state of the stable variables
    playerDecks := savedPlayerDecks;

    referrals := HashMap.fromIter(_referrals.vals(), 0, Principal.equal, Principal.hash);

    generalUserProgress := HashMap.fromIter(_generalUserProgress.vals(), 0, Principal.equal, Principal.hash);
    missions := HashMap.fromIter(_missions.vals(), 0, Utils._natEqual, Utils._natHash);
    activeMissions := HashMap.fromIter(_activeMissions.vals(), 0, Utils._natEqual, Utils._natHash);
    claimedRewards := HashMap.fromIter(_claimedRewards.vals(), 0, Principal.equal, Principal.hash);

    individualAchievements := HashMap.fromIter(_individualAchievements.vals(), 0, Utils._natEqual, Utils._natHash);
    achievements := HashMap.fromIter(_achievements.vals(), 0, Utils._natEqual, Utils._natHash);

    userMissionProgress := HashMap.fromIter(_userMissionProgress.vals(), 0, Principal.equal, Principal.hash);
    userMissions := HashMap.fromIter(_userMissions.vals(), 0, Principal.equal, Principal.hash);
    userMissionCounters := HashMap.fromIter(_userMissionCounters.vals(), 0, Principal.equal, Principal.hash);
    userClaimedRewards := HashMap.fromIter(_userClaimedRewards.vals(), 0, Principal.equal, Principal.hash);

    basicStats := HashMap.fromIter(_basicStats.vals(), 0, Utils._natEqual, Utils._natHash);
    playerGamesStats := HashMap.fromIter(_playerGamesStats.vals(), 0, Principal.equal, Principal.hash);
    onValidation := HashMap.fromIter(_onValidation.vals(), 0, Utils._natEqual, Utils._natHash);
    countedMatches := HashMap.fromIter(_countedMatches.vals(), 0, Utils._natEqual, Utils._natHash);

    searching := HashMap.fromIter(_searching.vals(), 0, Utils._natEqual, Utils._natHash);
    playerStatus := HashMap.fromIter(_playerStatus.vals(), 0, Principal.equal, Principal.hash);
    inProgress := HashMap.fromIter(_inProgress.vals(), 0, Utils._natEqual, Utils._natHash);
    finishedGames := HashMap.fromIter(_finishedGames.vals(), 0, Utils._natEqual, Utils._natHash);

    // Restore the state of the achievement-related stable variables
    achievementCategories := HashMap.fromIter(_achievementCategories.vals(), 0, Utils._natEqual, Utils._natHash);
    achievements := HashMap.fromIter(_achievements.vals(), 0, Utils._natEqual, Utils._natHash);
    individualAchievements := HashMap.fromIter(_individualAchievements.vals(), 0, Utils._natEqual, Utils._natHash);

    userProgress := HashMap.fromIter(_userProgress.vals(), 0, Principal.equal, Principal.hash);

    claimedIndividualAchievementRewards := HashMap.fromIter(_claimedIndividualAchievementRewards.vals(), 0, Principal.equal, Principal.hash);
    claimedAchievementLineRewards := HashMap.fromIter(_claimedAchievementLineRewards.vals(), 0, Principal.equal, Principal.hash);
    claimedCategoryAchievementRewards := HashMap.fromIter(_claimedCategoryAchievementRewards.vals(), 0, Principal.equal, Principal.hash);

    userBasicInfo := HashMap.fromIter(_userBasicInfo.vals(), 0, Principal.equal, Principal.hash);
    userNetwork := HashMap.fromIter(_userNetwork.vals(), 0, Principal.equal, Principal.hash);
  };
  // #endregion

  //#region |Soul NFT|

  private type UpdateResult = {
    #Ok;
    #Err : Text;
  };

  stable var savedPlayerDecks : Trie<Principal, PlayerGameData> = Trie.empty();
  stable var playerDecks : Trie<Principal, PlayerGameData> = savedPlayerDecks;

  private func _keyFromPrincipal(p : Principal) : Key<Principal> {
    { hash = Principal.hash p; key = p };
  };
  public shared (msg) func storeCurrentDeck(newDeck : [TypesICRC7.TokenId]) : async Bool {
    // Iterate over each token ID and check ownership
    for (tokenId in newDeck.vals()) {
      let ownerResult = await icrc7_owner_of(tokenId);
      let owner = switch (ownerResult) {
        case (#Ok(account)) account.owner;
        case (#Err(_)) return false; // If the token doesn't exist, return false
      };

      // Check if the caller is the owner of the token
      if (Principal.notEqual(owner, msg.caller)) {
        Debug.print("Ownership check failed for token ID: " # Nat.toText(tokenId) # " - Owner: " # Principal.toText(owner));
        return false; // If any token is not owned by the caller, reject the request
      };
    };

    // If all ownership checks pass, store the deck
    let playerData : PlayerGameData = {
      deck = newDeck;
      // Add other relevant fields if necessary
    };

    playerDecks := Trie.put(playerDecks, _keyFromPrincipal(msg.caller), Principal.equal, playerData).0;

    Debug.print("Stored current deck for player: " # Principal.toText(msg.caller) # " with deck: " # debug_show (newDeck));
    return true;
  };
  private func storeDeck(caller : Principal, newDeck : [TypesICRC7.TokenId]) : async Bool {
    // Iterate over each token ID and check ownership
    for (tokenId in newDeck.vals()) {
      let ownerResult = await icrc7_owner_of(tokenId);
      let owner = switch (ownerResult) {
        case (#Ok(account)) account.owner;
        case (#Err(_)) return false; // If the token doesn't exist, return false
      };

      // Check if the caller is the owner of the token
      if (Principal.notEqual(owner, caller)) {
        Debug.print("Ownership check failed for token ID: " # Nat.toText(tokenId) # " - Owner: " # Principal.toText(owner));
        return false; // If any token is not owned by the caller, reject the request
      };
    };

    // If all ownership checks pass, store the deck
    let playerData : PlayerGameData = {
      deck = newDeck;
      // Add other relevant fields if necessary
    };

    playerDecks := Trie.put(playerDecks, _keyFromPrincipal(caller), Principal.equal, playerData).0;

    Debug.print("Stored current deck for player: " # Principal.toText(caller) # " with deck: " # debug_show (newDeck));
    return true;
  };
  public query func getPlayerDeck(principal : Principal) : async ?[TypesICRC7.TokenId] {
    let playerDataOpt = Trie.find(playerDecks, _keyFromPrincipal(principal), Principal.equal);

    switch (playerDataOpt) {
      case (?playerData) {
        return ?playerData.deck;
      };
      case null {
        return null; // No deck found for the given principal
      };
    };
  };
  func setGameOver(caller : Principal) : async (Bool, Bool, ?Principal) {
    switch (playerStatus.get(caller)) {
      case (null) {
        return (false, false, null);
      };
      case (?status) {
        switch (inProgress.get(status.matchID)) {
          case (null) {
            switch (searching.get(status.matchID)) {
              case (null) {
                switch (finishedGames.get(status.matchID)) {
                  case (null) {
                    return (false, false, null);
                  };
                  case (?match) {
                    // Game is not on the searching or in-progress list, so we just remove the status from the player
                    playerStatus.delete(caller);
                    return (true, caller == match.player1.id, getOtherPlayer(match, caller));
                  };
                };
              };
              case (?match) {
                // Game is on Searching list, so we remove it, add it to the finished list and remove the status from the player
                finishedGames.put(status.matchID, match);
                searching.delete(status.matchID);
                playerStatus.delete(caller);
                return (true, caller == match.player1.id, getOtherPlayer(match, caller));
              };
            };
          };
          case (?match) {
            // Game is on in-progress list, so we remove it, add it to the finished list and remove the status from the player
            finishedGames.put(status.matchID, match);
            inProgress.delete(status.matchID);
            playerStatus.delete(caller);
            return (true, caller == match.player1.id, getOtherPlayer(match, caller));
          };
        };
      };
    };
  };
  public func handleCombatXP(deck : [TypesICRC7.TokenId], totalXP : Nat) : async [TypesICRC7.TokenId] {
    let selectedUnits = await selectRandomUnits(deck);

    let xpDistribution = await distributeXP(totalXP, selectedUnits);

    let updatedUnits = await applyXPToUnits(selectedUnits, xpDistribution);

    return updatedUnits;
  };
  // Function to randomly select 3 units from the player's deck
  public func selectRandomUnits(deck : [TypesICRC7.TokenId]) : async [TypesICRC7.TokenId] {
    let indices : [Nat] = Array.tabulate(deck.size(), func(i : Nat) : Nat { i });
    let shuffledIndices = Utils.shuffleArray(indices);
    let selectedUnitsBuffer = Buffer.Buffer<TypesICRC7.TokenId>(3);

    for (i in Iter.range(0, 2)) {
      selectedUnitsBuffer.add(deck[shuffledIndices[i]]);
    };

    return Buffer.toArray(selectedUnitsBuffer);
  };
  func distributeXP(totalXP : Nat, selectedUnits : [TypesICRC7.TokenId]) : async [Nat] {
    let totalCombatXP = totalXP;
    var xpDistribution = Buffer.Buffer<Nat>(3);

    // Use Time.now() as the seed
    let timeNow : Nat64 = Nat64.fromIntWrap(Time.now());
    let seed : Nat32 = Nat32.fromNat(Nat64.toNat(timeNow) % 100_000_000); // Convert to Nat32 after extracting the last 8 digits
    let _prng = PseudoRandomX.fromSeed(seed, #xorshift32);

    // Collect inverted weights based on rarity, adjusted to use Nat
    var weights = Buffer.Buffer<Nat>(3);
    var totalWeight : Nat = 0;

    for (i in Iter.range(0, 2)) {
      let unit = selectedUnits[i];
      let metadataResult = await icrc7_metadata(unit); // Await the async call
      let rarityWeight : Nat = switch (metadataResult) {
        case (#Ok(metadata)) {
          switch (metadata.general.rarity) {
            case (?1) 4; // Common - highest weight
            case (?2) 3; // Rare
            case (?3) 2; // Epic
            case (?4) 1; // Legendary - lowest weight
            case (null) 4; // Default to common if rarity is null
            case (?_) 4; // Handle any other unspecified rarity values, defaulting to common
          };
        };
        case (#Err(_)) 4; // In case of an error, assign default common weight
      };
      weights.add(rarityWeight);
      totalWeight += rarityWeight; // Sum the total weight
    };

    // Distribute XP based on inverted weighted randomization using pure Nat
    for (i in Iter.range(0, 2)) {
      let weight = weights.get(i);
      let unitXP = (totalCombatXP * weight) / totalWeight; // Distribute XP proportionally
      xpDistribution.add(unitXP);
    };

    return Buffer.toArray(xpDistribution);
  };
  func applyXPToUnits(selectedUnits : [TypesICRC7.TokenId], xpDistribution : [Nat]) : async [TypesICRC7.TokenId] {
    var updatedUnits = Buffer.Buffer<TypesICRC7.TokenId>(3); // Using a Buffer for efficient memory management

    for (i in Iter.range(0, 2)) {
      let unit = selectedUnits[i];
      let xp = xpDistribution[i];

      // Retrieve the full TokenMetadata, including owner and metadata
      let tokenResult = await icrc7_metadata(unit);

      switch (tokenResult) {
        case (#Ok(tokenMetadata)) {
          // `tokenMetadata` is of type `TokenMetadata`, so access the `metadata` field directly
          let originalMetadata = tokenMetadata;

          // Create a new SoulMetadata with updated combatExperience while preserving the birth date
          let newSoul = switch (originalMetadata.soul) {
            case (?soul) {
              {
                birth = soul.birth; // Preserve the original birth date
                gamesPlayed = soul.gamesPlayed;
                totalKills = soul.totalKills;
                totalDamageDealt = soul.totalDamageDealt;
                combatExperience = soul.combatExperience + xp;
              };
            };
            case null {
              {
                birth = Time.now();
                gamesPlayed = ?0;
                totalKills = ?0;
                totalDamageDealt = ?0;
                combatExperience = xp;
              };
            };
          };

          // Now we should proceed with updating the metadata
          let newMetadata = {
            category = originalMetadata.category;
            general = originalMetadata.general;
            basic = originalMetadata.basic;
            skills = originalMetadata.skills;
            skins = originalMetadata.skins;
            soul = ?newSoul;
          };

          // Update the token metadata
          let updateResult = await _updateTokenMetadata(unit, ?newMetadata);

          // Handle the result
          switch (updateResult) {
            case (#Ok(_)) updatedUnits.add(unit);
            case (#Err(_)) {}; // Handle update errors, if necessary
          };
        };
        case (#Err(_)) {}; // Handle retrieval errors, if necessary
      };
    };

    // Convert Buffer to Array before returning
    return Buffer.toArray(updatedUnits);
  };
  private func _updateTokenMetadata(tokenId : TypesICRC7.TokenId, newMetadata : ?TypesICRC7.Metadata) : async UpdateResult {
    // Update the token metadata in the Trie
    let tokenExists = _exists(tokenId);
    if (tokenExists) {
      _updateToken(tokenId, null, newMetadata); // Update the metadata without modifying ownership
      return #Ok(());
    } else {
      return #Err("Token does not exist");
    };
  };
  public func updateSoulNFTPlayed(playerDeck : [TypesICRC7.TokenId]) : async [TypesICRC7.TokenId] {
    var updatedUnits = Buffer.Buffer<TypesICRC7.TokenId>(playerDeck.size());

    for (i in Iter.range(0, playerDeck.size() - 1)) {
      let unit = playerDeck[i];

      // Retrieve the full TokenMetadata, including owner and metadata
      let tokenResult = await icrc7_metadata(unit);

      switch (tokenResult) {
        case (#Ok(tokenMetadata)) {
          // `tokenMetadata` is of type `TokenMetadata`, so access the `metadata` field directly
          let originalMetadata = tokenMetadata;

          // Create a new SoulMetadata with updated gamesPlayed
          let newSoul = switch (originalMetadata.soul) {
            case (?soul) {
              {
                birth = soul.birth;
                gamesPlayed = switch (soul.gamesPlayed) {
                  case (?games) ?(games + 1);
                  case null ?1;
                };
                totalKills = soul.totalKills;
                totalDamageDealt = soul.totalDamageDealt;
                combatExperience = soul.combatExperience;
              };
            };
            case null {
              {
                birth = Time.now();
                gamesPlayed = ?1;
                totalKills = ?0;
                totalDamageDealt = ?0;
                combatExperience = 0;
              };
            };
          };

          // Now we should proceed with updating the metadata
          let newMetadata = {
            category = originalMetadata.category;
            general = originalMetadata.general;
            basic = originalMetadata.basic;
            skills = originalMetadata.skills;
            skins = originalMetadata.skins;
            soul = ?newSoul;
          };

          // Update the token metadata
          let updateResult = await _updateTokenMetadata(unit, ?newMetadata);

          // Handle the result
          switch (updateResult) {
            case (#Ok(_)) updatedUnits.add(unit);
            case (#Err(_)) {}; // Handle update errors, if necessary
          };
        };
        case (#Err(_)) {}; // Handle retrieval errors, if necessary
      };
    };

    // Convert Buffer to Array before returning
    return Buffer.toArray(updatedUnits);
  };
  // #endregion

  //#region |Avatars and Titles|

  public type Avatar = {
    id : Nat;
    description : Text;
  };

  public type Title = {
    id : Nat;
    title : Text;
    description : Text;
  };

  private let avatars : [Avatar] = [
    { id = 1; description = "Default avatar" },
    { id = 2; description = "Galactic Explorer" },
    { id = 3; description = "Stellar Voyager" },
    { id = 4; description = "Nebula Wanderer" },
    { id = 5; description = "Cosmic Drifter" },
    { id = 6; description = "Asteroid Miner" },
    { id = 7; description = "Meteor Hunter" },
    { id = 8; description = "Celestial Scout" },
    { id = 9; description = "Orbital Mechanic" },
    { id = 10; description = "Starship Engineer" },
    { id = 11; description = "Quantum Navigator" },
    { id = 12; description = "Space Pioneer" },
    {
      id = 98;
      description = "Cosmicrafts Ambassador Avatar, awarded for finishing referrals program";
    },
    {
      id = 99;
      description = "An awesome Avatar, rewarded for finishing the Tiers Referral Program";
    },
  ];

  private let titles : [Title] = [
    {
      id = 1;
      title = "Starbound Initiate";
      description = "Welcome to Cosmicrafts commander, you are now in the Metaverse";
    },
    {
      id = 98;
      title = "Cosmicrafts Ambassador";
      description = "The Spiral is strong in you, thank you for your service commander";
    },
    {
      id = 99;
      title = "Cosmicrafts Founder";
      description = "Founder of Cosmicrafts you will be remembered forever across the Metaverse";
    },
    {
      id = 91;
      title = "Twitter Ambassador";
      description = "Awarded for your outstanding presence on Twitter.";
    },
    {
      id = 92;
      title = "Discord Ambassador";
      description = "Awarded for your strong community engagement on Discord.";
    },
    {
      id = 93;
      title = "DSCVR Ambassador";
      description = "Awarded for your active participation on DSCVR.";
    },
    {
      id = 94;
      title = "Tiktok Ambassador";
      description = "Awarded for spreading the word on Tiktok.";
    },
    {
      id = 95;
      title = "Facebook Ambassador";
      description = "Awarded for your influence on Facebook.";
    },
    {
      id = 96;
      title = "Instagram Ambassador";
      description = "Awarded for your visual storytelling on Instagram.";
    },
  ];

  // Stable variables to store player-specific data
  stable var _availableTitles : [(Principal, [Nat])] = [];
  stable var _selectedTitles : [(Principal, Nat)] = [];
  stable var _availableAvatars : [(Principal, [Nat])] = [];
  stable var _selectedAvatars : [(Principal, Nat)] = [];

  // HashMaps to manage player-specific data
  var availableTitles : HashMap.HashMap<Principal, [Nat]> = HashMap.fromIter(_availableTitles.vals(), 0, Principal.equal, Principal.hash);
  var selectedTitles : HashMap.HashMap<Principal, Nat> = HashMap.fromIter(_selectedTitles.vals(), 0, Principal.equal, Principal.hash);
  var availableAvatars : HashMap.HashMap<Principal, [Nat]> = HashMap.fromIter(_availableAvatars.vals(), 0, Principal.equal, Principal.hash);
  var selectedAvatars : HashMap.HashMap<Principal, Nat> = HashMap.fromIter(_selectedAvatars.vals(), 0, Principal.equal, Principal.hash);

  // Functions to get avatar and title by ID
  public func getAvatarById(id : Nat) : async Avatar {
    return switch (Array.find<Avatar>(avatars, func(a) { a.id == id })) {
      case (?avatar) avatar;
      case (null) {
        // Handle the case where the ID is not found, but since this shouldn't happen, we return a default avatar or an error
        { id = 0; description = "Unknown Avatar" };
      };
    };
  };

  public func getTitleById(id : Nat) : async Title {
    return switch (Array.find<Title>(titles, func(t) { t.id == id })) {
      case (?title) title;
      case (null) {
        // Handle the case where the ID is not found, but since this shouldn't happen, we return a default title or an error
        {
          id = 0;
          title = "Unknown Title";
          description = "Unknown Description";
        };
      };
    };
  };

  // Function to add an avatar to a user
  public shared (msg) func addAvatarToUser(newAvatarId : Nat) : async (Bool, Text) {
    let avatar = await getAvatarById(newAvatarId); // Ensure this is correctly awaited if needed
    let userAvatars = switch (availableAvatars.get(msg.caller)) {
      case (null) { [] };
      case (?avatars) { avatars };
    };

    if (Array.find<Nat>(userAvatars, func(a) { a == newAvatarId }) == null) {
      let updatedAvatarsBuffer = Buffer.Buffer<Nat>(userAvatars.size() + 1);
      for (avatarId in userAvatars.vals()) {
        updatedAvatarsBuffer.add(avatarId);
      };
      updatedAvatarsBuffer.add(newAvatarId);
      availableAvatars.put(msg.caller, Buffer.toArray(updatedAvatarsBuffer));
      return (true, "Avatar added successfully: " # avatar.description);
    };
    return (false, "Avatar already exists for the user: " # avatar.description);
  };

  // Function to update the selected avatar for a user
  public shared (msg) func updateAvatar(avatarId : Nat) : async (Bool, Text) {
    let userAvatarsOpt = availableAvatars.get(msg.caller);
    switch (userAvatarsOpt) {
      case (null) {
        return (false, "No avatars available for the user.");
      };
      case (?userAvatars) {
        if (Array.find<Nat>(userAvatars, func(a) { a == avatarId }) != null) {
          selectedAvatars.put(msg.caller, avatarId);

          // Update the player's avatar in their profile
          switch (userBasicInfo.get(msg.caller)) {
            case (?player) {
              let updatedPlayer = {
                player with avatar = avatarId
              };
              userBasicInfo.put(msg.caller, updatedPlayer);
            };
            case (null) {
              return (false, "Player not found");
            };
          };

          return (true, "Avatar selected successfully.");
        };
        return (false, "Avatar not found in the user's available avatars.");
      };
    };
  };

  // Function to add a title to a user
  public shared (msg) func addTitleToUser(newTitleId : Nat) : async (Bool, Text) {
    let title = await getTitleById(newTitleId);
    let userTitles = switch (availableTitles.get(msg.caller)) {
      case (null) { [] };
      case (?titles) { titles };
    };

    if (Array.find<Nat>(userTitles, func(t) { t == newTitleId }) == null) {
      let updatedTitlesBuffer = Buffer.Buffer<Nat>(userTitles.size() + 1);
      for (titleId in userTitles.vals()) {
        updatedTitlesBuffer.add(titleId);
      };
      updatedTitlesBuffer.add(newTitleId);
      availableTitles.put(msg.caller, Buffer.toArray(updatedTitlesBuffer));
      return (true, "Title added successfully: " # title.description);
    };
    return (false, "Title already exists for the user: " # title.description);
  };

  // Function to update the selected title for a user
  public shared (msg) func updateTitle(titleId : Nat) : async (Bool, Text) {
    let userTitlesOpt = availableTitles.get(msg.caller);
    switch (userTitlesOpt) {
      case (null) {
        return (false, "No titles available for the user.");
      };
      case (?userTitles) {
        if (Array.find<Nat>(userTitles, func(t) { t == titleId }) != null) {
          // Retrieve the title text using the titleId
          let title = await getTitleById(titleId);
          selectedTitles.put(msg.caller, titleId);

          // Update the player's title in their profile with the actual title text
          switch (userBasicInfo.get(msg.caller)) {
            case (?player) {
              let updatedPlayer = {
                player with title = ?title.title
              };
              userBasicInfo.put(msg.caller, updatedPlayer);
            };
            case (null) {
              return (false, "Player not found");
            };
          };

          return (true, "Title selected successfully: " # title.title);
        };
        return (false, "Title not found in the user's available titles.");
      };
    };
  };

  // Query function to get the selected avatar for a user
  public query (msg) func getSelectedAvatar() : async ?Nat {
    return selectedAvatars.get(msg.caller);
  };

  // Query function to get the selected title for a user
  public query (msg) func getSelectedTitle() : async ?Nat {
    return selectedTitles.get(msg.caller);
  };

  // Query function to get available avatars for a user
  public query (msg) func getAvailableAvatars() : async [Nat] {
    switch (availableAvatars.get(msg.caller)) {
      case (null) {
        return [];
      };
      case (?avatars) {
        return avatars;
      };
    };
  };

  // Query function to get available titles for a user
  public query (msg) func getAvailableTitles() : async [Nat] {
    switch (availableTitles.get(msg.caller)) {
      case (null) {
        return [];
      };
      case (?titles) {
        return titles;
      };
    };
  };

  // Query function to get the complete Avatar details for the user
  public query (msg) func getAvailableAvatarDetails() : async [Avatar] {
    let avatarIds = switch (availableAvatars.get(msg.caller)) {
      case (null) { [] };
      case (?avatars) { avatars };
    };

    let avatarDetails : [Avatar] = Array.flatten(
      Array.map<Nat, [Avatar]>(
        avatarIds,
        func(id : Nat) : [Avatar] {
          switch (Array.find<Avatar>(avatars, func(a) { a.id == id })) {
            case (?avatar) [avatar];
            case (null) []; // Return an empty list for unmatched IDs
          };
        },
      )
    );

    return avatarDetails;
  };

  // Query function to get the complete Title details for the user
  public query (msg) func getAvailableTitleDetails() : async [Title] {
    let titleIds = switch (availableTitles.get(msg.caller)) {
      case (null) { [] };
      case (?titles) { titles };
    };

    let titleDetails : [Title] = Array.flatten(
      Array.map<Nat, [Title]>(
        titleIds,
        func(id : Nat) : [Title] {
          switch (Array.find<Title>(titles, func(t) { t.id == id })) {
            case (?title) [title];
            case (null) []; // Return an empty list for unmatched IDs
          };
        },
      )
    );

    return titleDetails;
  };
  // #endregion

  //#region |Referrals|

  public type RNode = {
    id : Principal;
    username : Text;
    multiplier : Float;
    earnings : Float;
    referralCode : Text;
    referrerId : ?Principal;
    nodes : [RNode];
  };

  stable var _referrals : [(Principal, RNode)] = [];
  var referrals : HashMap.HashMap<Principal, RNode> = HashMap.fromIter(
    _referrals.vals(),0,Principal.equal,Principal.hash);
  
  stable var _refCodes : [Text] = [];
  var refCodes : Buffer.Buffer<Text> = Buffer.Buffer<Text>(_refCodes.size());
  let cosmicWords = ["PUMP", "WAGMI", "SHILL", "GWEI", "SATOSHI", "MOON", "WHALE", "LAMBO", "HODL", "FOMO"];

  // Get All Referrals
  public query func getAllReferrals() : async ?[(Principal, RNode)] {
    return ?Iter.toArray(referrals.entries());
  };

  // Get the referrer id by code
  public query func getReferrerIdByCode(code : Text) : async ?Principal {
    for ((_, node) in referrals.entries()) {
      if (node.referralCode == code) {
        return ?node.id;
      };
    };
    return null;
  };

  // Get the referral code by id
  public query func getReferralCode(id : Principal) : async ?Text {
    for ((_, node) in referrals.entries()) {
      if (node.id == id) {
        return ?node.referralCode;
      };
    };
    return null;
  };

  // Get the referral node by id
  public query func getReferralNodeById(id : Principal) : async ?RNode {
    for ((_, node) in referrals.entries()) {
      if (node.id == id) {
        return ?node;
      };
    };
    return null;
  };

  // Get the count of the matching referrals searched by id
  public query func getReferralCountById(id : Principal) : async Int {
    var count = 0;
    for ((_, node) in referrals.entries()) {
      if (node.referrerId == ?id) {
        count += 1;
      };
    };
    return count;
  };

  // Get an array of getReferralCount from all the referrals
  public func getAllReferralCounts() : async [(Principal, Int, Float, Float)] {
    var counts : [(Principal, Int, Float, Float)] = [];
    for ((_, node) in referrals.entries()) {
      let count = await getReferralCountById(node.id);
      counts := Array.append<(Principal, Int, Float, Float)>(
        counts,
        [(node.id, count, node.multiplier, node.earnings)],
      );
    };
    return counts;
  };

  // Calculate the multiplier for the referral
  public func calculateMultiplier(id : Principal) : async (Int, Float) {
    let n = await getReferralCountById(id);
    if (n == 0) {
      return (n, 1.0);
    };
    Debug.print("ID: " # Principal.toText(id));
    Debug.print("Total referrals: " # Int.toText(n));
    var x = 0.0;

    for (count in Iter.range(0, n)) {
      let i = Float.fromInt(count + 1);
      x += 1.0 + 1.0 / i;
      Debug.print(Int.toText(count) # " referral's with  " # Float.toText(x - 1) # " of multiplier");
    };
    return (n, x - 1);
  };

  // Helper function to build the referral tree
  private func buildTree(nodeId : Principal) : async ?RNode {
    switch (await getReferralNodeById(nodeId)) {
      case (?node) {
        var childNodes : [RNode] = [];
        for ((_, refNode) in referrals.entries()) {
          if (refNode.referrerId == ?nodeId) {
            switch (await buildTree(refNode.id)) {
              case (?childNode) {
                childNodes := Array.append<RNode>(childNodes, [childNode]);
              };
              case null {};
            };
          };
        };
        return 
      ?{ node 
      with nodes = childNodes 
      };
      };
      case null {
        return null;
      };
    };
  };

  // Get the referral tree for a specific ID
  public shared func getReferralTree(id : Principal) : async ?RNode {
    return await buildTree(id);
  };

  //Check if the referral is linked
  public func isReferralLinked(id : Principal) : async Bool {
    for ((_, node) in referrals.entries()) {
      if (node.id == id) {
        return true;
      };
    };
    return false;
  };

  // Link the referral to the account
  public func linkReferral(id : Principal, username : Text, code : Text) : async (Bool, Text) {

    if (await isReferralLinked(id)) {
      return (false, "Referral already linked");
    };

    Debug.print("Getting the referral id");
    let n = await getReferrerIdByCode(code);
    let foundId = switch (n) {
      case (?principal) {
        Debug.print(
          "Referral id found: " #
          Principal.toText(principal)
        );
        principal;
      };
      case (null) {
        Debug.print("Referral code not found");
        if (referrals.size() == 0) {
          Debug.print("Linking first account");
          let (refs, mult) = await calculateMultiplier(id);
          let earn = Float.fromInt(refs) * mult;
          let newNode : RNode = {
            id = id;
            username = "user1";
            multiplier = mult;
            earnings = earn;
            referralCode = code;
            referrerId = ?Principal.fromText("aaaaa-aa");
            nodes = [];
          };
          referrals.put(newNode.id, newNode);
          return (true, "Referral linked");
        };
        return (true, "Referral not linked");
      };
    };

    Debug.print("Finding referrer node by id");
    let node = await getReferralNodeById(foundId);
    let referrerNode = switch (node) {
      case (?node) {
        node;
      };
      case (null) {
        return (false, "Error. Referrer not found");
      };
    };

    Debug.print("Updating referrer nodes");
    let newNode : RNode = {
      id = id;
      username = username;
      multiplier = 1.0;
      earnings = 0.0;
      referralCode = await generateReferralCode();
      referrerId = ?foundId;
      nodes = [];
    };
    var updatedNode = {
      referrerNode with
      nodes = Array.append<RNode>(
        referrerNode.nodes,
        [newNode],
      );
    };
    referrals.put(updatedNode.id, updatedNode);
    referrals.put(newNode.id, newNode);

    Debug.print("Calculating earnings and multiplier");
    let (refsReferrer, multReferrer) = await calculateMultiplier(foundId);
    let earnReferrer = Float.fromInt(refsReferrer) * multReferrer;

    Debug.print(
      "Referrer has " # Int.toText(refsReferrer) #
      " referrals with " # Float.toText(multReferrer)
      # " of multiplier"
    );

    Debug.print("Updating referrer");
    var updReferrerNode = {
      referrerNode with
      multiplier = multReferrer;
      earnings = earnReferrer;
    };
    referrals.put(updReferrerNode.id, updReferrerNode);
    return (true, "Referral linked");
  };

  // Get the top position of the referral  
  public func getTopPosition(id:Principal) : async Nat {
    let allReferrals : [(Principal, RNode)] = Iter.toArray(referrals.entries());
    let sortedReferrals : [(Principal, RNode)] = Array.sort(
      allReferrals,
      func(a : (Principal, RNode), b : (Principal, RNode)) : {
        #less;
        #equal;
        #greater;
      } {
        if (a.1.earnings > b.1.earnings) {
          #less;
        } else if (a.1.earnings < b.1.earnings) {
          #greater;
        } else {
          #equal;
        };
      },
    );
    var position = 0;
    for ((playerId, _) in Iter.fromArray(sortedReferrals)) {
      position := position + 1;
      if (playerId == id) {
          return position;
      };
    };
    return 0;
  };

  // Util to enerate a short UUID
  private func generateShortUUID() : async Nat {
    let randomBytes = await Random.blob();
    var uuid : Nat = 0;
    let byteArray = Blob.toArray(randomBytes);
    for (i in Iter.range(0, 3)) {
      uuid := Nat.add(
        Nat.bitshiftLeft(uuid, 8),
        Nat8.toNat(byteArray[i]),
      );
    };
    uuid := uuid % 10000;
    return uuid;
  };

  // Util to Generate a referral code
  private func generateReferralCode() : async Text {
    let uuid = await generateShortUUID();
    let indices : [Nat] = Array.tabulate(
      cosmicWords.size(),
      func(i : Nat) : Nat { i },
    );
    let shuffledIndices = Utils.shuffleArray(indices);
    let word = cosmicWords[shuffledIndices[0]];
    let referralCode = word # Nat.toText(uuid);
    referralCode;
  };

  // Util to generate n referral codes
  public func refCodeGen(n : Nat) : async (Bool, Text) {
    if (refCodes.size() > 0) {
      return (false, "Referral codes already generated");
    };
    for (i in Iter.range(0, n)) {
      let referralCode = await generateReferralCode();
      refCodes.add(referralCode);
    };
    return (true, "Referral codes generated");
  };
  // #endregion

  //#region |Tops|
 
  //////////////////////////
  //  ELOTop
  //
  public type ELOTop = {
    playerId : Principal;
    elo : Float;
    username : Text;
    avatar : Nat;
  };
  public query ({ caller }) func getTopELO(id: Principal, page : Nat) : async ?([ELOTop], Nat) {
    let buffer = Buffer.Buffer<(PlayerId, Float)>(userBasicInfo.size());
    for ((playerId, player) in userBasicInfo.entries()) {
      buffer.add((playerId, player.elo));
    };

    let allPlayersWithELO = Buffer.toArray(buffer);
    let sortedPlayers = Array.sort(
      allPlayersWithELO,
      func(a : (PlayerId, Float), b : (PlayerId, Float)) : {
        #less;
        #equal;
        #greater;
      } {
        if (a.1 > b.1) {
          #less;
        } else if (a.1 < b.1) {
          #greater;
        } else {
          #equal;
        };
      },
    );

    let pageSize = 10;
    let start = page * pageSize;
    let end = if (start + pageSize > Array.size(sortedPlayers)) {
      Array.size(sortedPlayers);
    } else {
      start + pageSize;
    };

    let paginatedPlayers : [(PlayerId, Float)] = Iter.toArray(
      Array.slice(sortedPlayers, start, end)
    );

    var topELOPlayers : [ELOTop] = [];
    for (entry in paginatedPlayers.vals()) {
      let playerId = entry.0;
      let elo = entry.1;
      let playerOpt = userBasicInfo.get(caller);
      let username = switch (playerOpt) {
        case (?player) { player.username };
        case (null) { "Unknown" };
      };
      let avatar = switch (playerOpt) {
        case (?player) { player.avatarId };
        case (null) { 0 };
      };

      let p : ELOTop = {
        playerId = playerId;
        elo = elo;
        username = username;
        avatar = avatar;
      };
      topELOPlayers := Array.append(topELOPlayers, [p]);
    };

    var position = 0;
    for ((playerId, _) in Iter.fromArray(sortedPlayers)) {
      position := position + 1;
      if (playerId == id) {
          return ?(topELOPlayers, position);
      };
    };

    return null;
  };

  //////////////////////////
  //  ReferralTop
  //
  public type Position = Nat;
  public type ReferralTop = {
    id : Principal;
    avatar : Nat;
    username : Text;
    multiplier : Float;
    referralCount : Int;
    earnings : Float;
    referralCode : Text;
  };
  public func getTopReferrals(id: Principal, page : Nat) : async ?([ReferralTop], Position) {

    let allReferrals : [(Principal, RNode)] = Iter.toArray(referrals.entries());
     
    let user = switch (userBasicInfo.get(id)) {
      case (?player) { player };
      case (null) { return null };
    };
  
    let sortedReferrals : [(Principal, RNode)] = Array.sort(
      allReferrals, func(a : (Principal, RNode), b : (Principal, RNode)) : 
      {#less; #equal;#greater;} {
        if (a.1.earnings > b.1.earnings) {
          #less;
        } else if (a.1.earnings < b.1.earnings) {
          #greater;
        } else {
          #equal;
        };
      },
    );

    let pageSize = 10;
    let start = page * pageSize;
    let end = if (start + pageSize > Array.size(sortedReferrals)) {
      Array.size(sortedReferrals);
    } else {
      start + pageSize;
    };

    let paginatedReferrals : [(Principal, RNode)] = Iter.toArray(
      Array.slice(sortedReferrals, start, end)
    );

   
    var topReferrals : [ReferralTop] = [];

     var countRefs = 0;
    for ((_, node) in referrals.entries()) {
      if (node.referrerId == ?id) {
        countRefs += 1;
      };
    };
    for (entry in paginatedReferrals.vals()) {

      let playerId = entry.0;
      let node = entry.1;
      let avatar = user.avatarId;
      let username = node.username;
      let multiplier = node.multiplier;
      let referralCount = countRefs;
      let earnings = node.earnings;
      let referralCode = node.referralCode;

      let referralTop : ReferralTop = {
        id = playerId;
        avatar = avatar;
        username = username;
        multiplier = multiplier;
        referralCount = referralCount;
        earnings = earnings;
        referralCode = referralCode;
      };
      topReferrals := Array.append<ReferralTop>(topReferrals, [referralTop]);
    };

    var position = 0;
    for ((playerId, _) in Iter.fromArray(sortedReferrals)) {
      position := position + 1;
      if (playerId == id) {
          return ?(topReferrals, position);
      };
    };
    return null;
  };

  //////////////////////////
  //  AchievementsTop
  //
  public type AchievementsTop = {
    playerId : Principal;
    totalAchievements : Nat;
    username : Text;
    avatar : Nat;
  };
  public query ({ caller }) func getTopAchievements(page : Nat) : async [AchievementsTop] {
    let buffer = Buffer.Buffer<(PlayerId, Nat)>(userProgress.size());
    for ((playerId, userCategoriesList) in userProgress.entries()) {
      var totalAchievements : Nat = 0;

      // Count category achievements based on progress
      for (category in userCategoriesList.vals()) {
        totalAchievements += category.progress;

        // Count line achievements based on progress
        for (achievementLine in category.achievements.vals()) {
          totalAchievements += achievementLine.progress;

          // Count individual achievements based on progress
          for (individualAchievement in achievementLine.individualAchievements.vals()) {
            totalAchievements += individualAchievement.progress;
          };
        };
      };

      buffer.add((playerId, totalAchievements));
    };

    let allPlayersWithAchievements = Buffer.toArray(buffer);
    let sortedPlayers = Array.sort(
      allPlayersWithAchievements,
      func(a : (PlayerId, Nat), b : (PlayerId, Nat)) : {
        #less;
        #equal;
        #greater;
      } {
        if (a.1 > b.1) {
          #less;
        } else if (a.1 < b.1) {
          #greater;
        } else {
          #equal;
        };
      },
    );

    let pageSize = 10;
    let start = page * pageSize;
    let end = if (start + pageSize > Array.size(sortedPlayers)) {
      Array.size(sortedPlayers);
    } else {
      start + pageSize;
    };

    let paginatedPlayers : [(PlayerId, Nat)] = Iter.toArray(
      Array.slice(sortedPlayers, start, end)
    );

    var topAchievementPlayers : [AchievementsTop] = [];
    for (entry in paginatedPlayers.vals()) {
      let playerId = entry.0;
      let totalAchievements = entry.1;

      let playerOpt = userBasicInfo.get(caller);
      let username = switch (playerOpt) {
        case (?player) { player.username };
        case (null) { "Unknown" };
      };
      let avatar = switch (playerOpt) {
        case (?player) { player.avatarId };
        case (null) { 0 };
      };

      let p : AchievementsTop = {
        playerId = playerId;
        totalAchievements = totalAchievements;
        username = username;
        avatar = avatar;
      };
      topAchievementPlayers := Array.append(topAchievementPlayers, [p]);
    };
    return topAchievementPlayers;
  };

  //////////////////////////
  //  NFTTop
  //
  public type NFTTop = {
    playerId : Principal;
    avatar : Nat;
    username :Text;
    level : Nat;
    nftCount : Nat;
  };
  public func getTopNFT(page : Nat) : async [NFTTop] {
    let buffer = Buffer.Buffer<(PlayerId, Nat)>(userBasicInfo.size());
    for ((playerId, player) in userBasicInfo.entries()) {
      let nftCount = (await getNFTs(playerId)).size();
      buffer.add((playerId, nftCount));
    };
    let allPlayersWithNFTs = Buffer.toArray(buffer);
    let sortedPlayers = Array.sort(
      allPlayersWithNFTs,
      func(a : (PlayerId, Nat), b : (PlayerId, Nat)) : {
        #less;
        #equal;
        #greater;
      } {
        if (a.1 > b.1) {
          #less;
        } else if (a.1 < b.1) {
          #greater;
        } else {
          #equal;
        };
      },
    );

    let pageSize = 10;
    let start = page * pageSize;
    let end = if (start + pageSize > Array.size(sortedPlayers)) {
      Array.size(sortedPlayers);
    } else {
      start + pageSize;
    };

    let paginatedPlayers : [(PlayerId, Nat)] = Iter.toArray(
      Array.slice(sortedPlayers, start, end)
    );

    var topNFTPlayers : [NFTTop] = [];
    for (entry in paginatedPlayers.vals()) {
      let playerId = entry.0;
      let nftCount = entry.1;
      let playerOpt = userBasicInfo.get(playerId);
      let username = switch (playerOpt) {
        case (?player) { player.username };
        case (null) { "Unknown" };
      };
      let avatar = switch (playerOpt) {
        case (?player) { player.avatarId };
        case (null) { 0 };
      };
      let level = switch (playerOpt) {
        case (?player) { player.level };
        case (null) { 0 };
      };

      let p : NFTTop = {
        playerId = playerId;
        avatar = avatar;
        username = username;
        level = level;
        nftCount = nftCount;
      };
      topNFTPlayers := Array.append(topNFTPlayers, [p]);
    };
    return topNFTPlayers;
  };

  // #endregion

  //#region |Achievements|
  stable var achievementCategoryIDCounter : Nat = 1;
  stable var achievementIDCounter : Nat = 1;
  stable var individualAchievementIDCounter : Nat = 1;

  stable var _achievementCategories : [(Nat, AchievementCategory)] = [];
  stable var _achievements : [(Nat, AchievementLine)] = [];
  stable var _individualAchievements : [(Nat, IndividualAchievement)] = [];

  stable var _userProgress : [(PlayerId, [AchievementCategory])] = [];

  stable var _claimedIndividualAchievementRewards : [(PlayerId, [Nat])] = [];
  stable var _claimedAchievementLineRewards : [(PlayerId, [Nat])] = [];
  stable var _claimedCategoryAchievementRewards : [(PlayerId, [Nat])] = [];

  var achievementCategories : HashMap.HashMap<Nat, AchievementCategory> = HashMap.fromIter(_achievementCategories.vals(), 0, Utils._natEqual, Utils._natHash);
  var achievements : HashMap.HashMap<Nat, AchievementLine> = HashMap.fromIter(_achievements.vals(), 0, Utils._natEqual, Utils._natHash);
  var individualAchievements : HashMap.HashMap<Nat, IndividualAchievement> = HashMap.fromIter(_individualAchievements.vals(), 0, Utils._natEqual, Utils._natHash);

  var userProgress : HashMap.HashMap<PlayerId, [AchievementCategory]> = HashMap.fromIter(_userProgress.vals(), 0, Principal.equal, Principal.hash);

  var claimedIndividualAchievementRewards : HashMap.HashMap<PlayerId, [Nat]> = HashMap.fromIter(_claimedIndividualAchievementRewards.vals(), 0, Principal.equal, Principal.hash);
  var claimedAchievementLineRewards : HashMap.HashMap<PlayerId, [Nat]> = HashMap.fromIter(_claimedAchievementLineRewards.vals(), 0, Principal.equal, Principal.hash);
  var claimedCategoryAchievementRewards : HashMap.HashMap<PlayerId, [Nat]> = HashMap.fromIter(_claimedCategoryAchievementRewards.vals(), 0, Principal.equal, Principal.hash);

  public func initAchievements() : async Bool {

    // Check if achievements are already initialized
    if (achievementCategories.size() > 0) { return true };

    // Get the pre-defined "Tiers" category from the AchievementData module
    let tiersCategory = AchievementData.getTiersCategory();

    // Step 1: Create the category
    let (successCat, messageCat, categoryID) = await createAchievementCategory(tiersCategory.name, tiersCategory.reward);
    if (not successCat) {
      Debug.print("Failed to create category: " # messageCat);
      return false;
    };

    // Step 2: Iterate through the achievement lines in the category
    for (achievementLine in tiersCategory.achievements.vals()) {
      let (successAch, messageAch, achievementID) = await createAchievement(categoryID, achievementLine.name, achievementLine.reward);
      if (not successAch) {
        Debug.print("Failed to create achievement: " # messageAch);
        return false;
      };

      // Step 3: Iterate through the individual achievements in the line
      for (individualAchievement in achievementLine.individualAchievements.vals()) {
        let _successIndAch = await createIndividualAchievement(
          achievementID,
          individualAchievement.name,
          individualAchievement.achievementType,
          individualAchievement.requiredProgress,
          individualAchievement.reward,
        );
      };
    };
    Debug.print("Achievements initialized successfully");
    return true;
  };
  public func assignAchievementsToUser(user : PlayerId) : async ([AchievementCategory]) {

    let userProgressOpt = userProgress.get(user);

    var userCategoriesList : [AchievementCategory] = switch (userProgressOpt) {
      case (null) { [] };
      case (?categories) { categories };
    };

    let categorySet = Set.new<Nat>(
      userCategoriesList.size(),
      func(a, b) { a == b },
      func(a) { Utils._natHash(a) },
    );

    // Add existing category IDs to the set
    for (category in userCategoriesList.vals()) {
      Set.put(categorySet, category.id);
    };

    // Assign only new categories that are not already in the user's progress
    for ((id, category) in achievementCategories.entries()) {
      if (not Set.contains(categorySet, id)) {
        userCategoriesList := Array.append(userCategoriesList, [category]);
      };
    };

    // Update the unified progress map with the assigned categories
    userProgress.put(user, userCategoriesList);
    Debug.print("[assignAchievementsToUser] User progress after update: " # debug_show (userProgress.get(user)));
    userCategoriesList;
  };
  public shared ({ caller }) func assignAchievementsToUserByCaller() : async Bool {
    let userProgressOpt = userProgress.get(caller);

    var userCategoriesList : [AchievementCategory] = switch (userProgressOpt) {
      case (null) { return false };
      case (?categories) { categories };
    };

    let categorySet = Set.new<Nat>(
      userCategoriesList.size(),
      func(a, b) { a == b },
      func(a) { Utils._natHash(a) },
    );

    for (category in userCategoriesList.vals()) {
      Set.put(categorySet, category.id);
    };

    for ((id, category) in achievementCategories.entries()) {
      if (not Set.contains(categorySet, id)) {
        userCategoriesList := Array.append(userCategoriesList, [category]);
      };
    };

    userProgress.put(caller, userCategoriesList);
    Debug.print("[assignAchievementsToUser] User progress after update: " # debug_show (userProgress.get(caller)));
    return true;
  };
  public func getUserAchievements(user : PlayerId) : async [AchievementCategory] {
    let userProgressOpt = userProgress.get(user);
    switch (userProgressOpt) {
      case (null) {
        return await assignAchievementsToUser(user);
      };
      case (?userCategoriesList) {
        return userCategoriesList;
      };
    };
  };
  public shared ({ caller }) func getUserAchievementsByCaller() : async [AchievementCategory] {
    let userProgressOpt = userProgress.get(caller);

    switch (userProgressOpt) {
      case (null) {
        return await assignAchievementsToUser(caller);
      };
      case (?userCategoriesList) {
        return userCategoriesList;
      };
    };
  };
  public query func getAllAchievements() : async [AchievementCategory] {
    var categories : [AchievementCategory] = [];
    let iter = achievementCategories.vals();
    var nextItem = iter.next();

    // Iterar sobre todos los elementos y agregarlos a la lista
    while (nextItem != null) {
      switch (nextItem) {
        case (?value) {
          categories := Array.append(categories, [value]);
        };
        case (null) {};
      };
      nextItem := iter.next();
    };

    return categories;
  };
  private func findIndividualAchievement(userCategoriesList : [AchievementCategory], individualAchievementId : Nat) : (?AchievementCategory, ?AchievementLine, ?IndividualAchievement) {

    for (category in userCategoriesList.vals()) {
      for (achievementLine in category.achievements.vals()) {
        for (individualAchievement in achievementLine.individualAchievements.vals()) {
          if (individualAchievement.id == individualAchievementId) {
            return (?category, ?achievementLine, ?individualAchievement);
          };
        };
      };
    };

    return (null, null, null);
  };
  public func createAchievement(categoryId : Nat, name : Text, rewards : [AchievementReward]) : async (Bool, Text, Nat) {
    let id = achievementIDCounter;
    achievementIDCounter += 1;
    let newAchievement : AchievementLine = {
      id = id;
      name = name;
      individualAchievements = [];
      categoryId = categoryId;
      reward = rewards;
      requiredProgress = 0;
      completed = false;
      progress = 0;
      claimed = false;
    };
    achievements.put(id, newAchievement);
    let categoryOpt = achievementCategories.get(categoryId);
    switch (categoryOpt) {
      case (null) return (false, "Category not found", id);
      case (?category) {
        let updatedCategory = {
          category with
          achievements = Array.append(category.achievements, [newAchievement])
        };
        achievementCategories.put(categoryId, updatedCategory);
      };
    };
    Debug.print("[createAchievement] Achievement created with ID: " # Nat.toText(id));
    return (true, "Achievement created successfully", id);
  };
  public func createIndividualAchievement(achievementId : Nat, name : Text, achievementType : AchievementType, requiredProgress : Nat, rewards : [AchievementReward]) : async (Bool, Text, Nat) {
    let id = individualAchievementIDCounter;
    individualAchievementIDCounter += 1;
    let newIndividualAchievement : IndividualAchievement = {
      id = id;
      name = name;
      achievementType = achievementType;
      requiredProgress = requiredProgress;
      reward = rewards;
      achievementId = achievementId;
      completed = false;
      progress = 0;
      claimed = false;
    };
    individualAchievements.put(id, newIndividualAchievement);
    var achievementOpt = achievements.get(achievementId);
    switch (achievementOpt) {
      case (null) return (false, "Achievement not found", id);
      case (?achievement) {
        let updatedAchievement = {
          achievement with
          individualAchievements = Array.append(achievement.individualAchievements, [newIndividualAchievement])
        };
        let updatedAchievementsArray = await updateAchievementsArray(updatedAchievement.categoryId, updatedAchievement);
        achievements.put(achievementId, updatedAchievement);
        updateCategoryWithAchievement(updatedAchievement.categoryId, updatedAchievementsArray);
      };
    };
    Debug.print("[createIndividualAchievement] Individual Achievement created with ID: " # Nat.toText(id));
    return (true, "Individual Achievement created successfully", id);
  };
  public func createAchievementCategory(name : Text, rewards : [AchievementReward]) : async (Bool, Text, Nat) {
    let id = achievementCategoryIDCounter;
    achievementCategoryIDCounter += 1;

    let newCategory : AchievementCategory = {
      id = id;
      name = name;
      achievements = [];
      reward = rewards;
      requiredProgress = 0;
      completed = false;
      progress = 0;
      claimed = false;
    };

    achievementCategories.put(id, newCategory);
    Debug.print("[createAchievementCategory] Category created with ID: " # Nat.toText(id));

    return (true, "Category created successfully", id);
  };
  public shared func addProgressToIndividualAchievement(user : PlayerId, individualAchievementId : Nat, progressToAdd : Nat) : async Bool {
    // Get the user's progress structure from the unified HashMap
    let userProgressOpt = userProgress.get(user);

    switch (userProgressOpt) {
      case (null) {
        Debug.print("[addProgressToIndividualAchievement] User has no progress records.");
        return false;
      };
      case (?userCategoriesList) {
        // Find the category and achievement line containing the individual achievement
        let (category, achievementLine, individualAchievement) = findIndividualAchievement(userCategoriesList, individualAchievementId);

        switch (individualAchievement) {
          case (null) {
            Debug.print("[addProgressToIndividualAchievement] Individual Achievement not found.");
            return false;
          };
          case (?individualAchievement) {
            // Update the individual achievement's progress
            let newProgress = individualAchievement.progress + progressToAdd;
            let isCompleted = newProgress >= individualAchievement.requiredProgress;

            // Create the updated individual achievement
            let updatedIndividualAchievement : IndividualAchievement = {
              id = individualAchievement.id;
              achievementId = individualAchievement.achievementId;
              name = individualAchievement.name;
              achievementType = individualAchievement.achievementType;
              requiredProgress = individualAchievement.requiredProgress;
              reward = individualAchievement.reward;
              progress = newProgress;
              completed = isCompleted;
              claimed = individualAchievement.claimed; // Preserve the current claimed status
            };

            // Update the achievement line with the new individual achievement
            switch (achievementLine) {
              case (null) { return false };
              case (?achievementLine) {
                // Update the individual achievements array
                let updIndividual = Array.tabulate<IndividualAchievement>(
                  Array.size(achievementLine.individualAchievements),
                  func(i : Nat) : IndividualAchievement {
                    let indAch = achievementLine.individualAchievements[i];
                    if (indAch.id == individualAchievement.id) {
                      updatedIndividualAchievement;
                    } else {
                      indAch;
                    };
                  },
                );

                let lineProgress = if (isCompleted) achievementLine.progress + 1 else achievementLine.progress;
                let isLineCompleted = lineProgress >= achievementLine.requiredProgress;

                let updatedAchievementLine : AchievementLine = {
                  id = achievementLine.id;
                  name = achievementLine.name;
                  individualAchievements = updIndividual;
                  categoryId = achievementLine.categoryId;
                  reward = achievementLine.reward;
                  requiredProgress = achievementLine.requiredProgress;
                  completed = isLineCompleted;
                  progress = lineProgress;
                  claimed = achievementLine.claimed; // Preserve the current claimed status
                };

                // Update the category with the new achievement line
                switch (category) {
                  case (null) { return false };
                  case (?category) {
                    let updLines = Array.tabulate<AchievementLine>(
                      Array.size(category.achievements),
                      func(i : Nat) : AchievementLine {
                        let line = category.achievements[i];
                        if (line.id == updatedAchievementLine.id) {
                          updatedAchievementLine;
                        } else {
                          line;
                        };
                      },
                    );

                    let categoryProgress = if (isLineCompleted) category.progress + 1 else category.progress;
                    let isCategoryCompleted = categoryProgress >= category.requiredProgress;

                    let updatedCategory : AchievementCategory = {
                      id = category.id;
                      name = category.name;
                      achievements = updLines;
                      reward = category.reward;
                      requiredProgress = category.requiredProgress;
                      completed = isCategoryCompleted;
                      progress = categoryProgress;
                      claimed = category.claimed; // Preserve the current claimed status
                    };

                    // Update the user's progress
                    let updCategorieArray = Array.tabulate<AchievementCategory>(
                      Array.size(userCategoriesList),
                      func(i : Nat) : AchievementCategory {
                        let cat = userCategoriesList[i];
                        if (cat.id == updatedCategory.id) {
                          updatedCategory;
                        } else {
                          cat;
                        };
                      },
                    );

                    userProgress.put(user, updCategorieArray);

                    Debug.print("[addProgressToIndividualAchievement] Progress updated for Individual Achievement ID: " # Nat.toText(individualAchievementId));
                    return true;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  public func updateAvatarChangeAchievement(user : PlayerId) : async (Bool, Text) {
    let individualAchievementId : Nat = 3; // Replace with the actual ID for the Avatar Change Achievement
    let progressToAdd : Nat = 1;

    // Call the updated addProgressToIndividualAchievement function
    let progressUpdated = await addProgressToIndividualAchievement(user, individualAchievementId, progressToAdd);

    if (progressUpdated) {
      return (true, "Avatar Change Achievement updated successfully.");
    } else {
      return (false, "Failed to update Avatar Change Achievement.");
    };
  };
  public func updateUpgradeNFTAchievement(user : PlayerId) : async (Bool, Text) {
    let individualAchievementId : Nat = 5; // Replace with the actual ID for the Upgrade NFT Achievement
    let progressToAdd : Nat = 1;

    // Call the updated addProgressToIndividualAchievement function
    let progressUpdated = await addProgressToIndividualAchievement(user, individualAchievementId, progressToAdd);

    if (progressUpdated) {
      return (true, "Upgrade NFT Achievement updated successfully.");
    } else {
      return (false, "Failed to update Upgrade NFT Achievement.");
    };
  };
  public func updateAddFriendAchievement(user : PlayerId) : async (Bool, Text) {
    let individualAchievementId : Nat = 4; // Replace with the actual ID for the Add Friend Achievement
    let progressToAdd : Nat = 1;

    // Call the updated addProgressToIndividualAchievement function
    let progressUpdated = await addProgressToIndividualAchievement(user, individualAchievementId, progressToAdd);

    if (progressUpdated) {
      return (true, "Add Friend Achievement updated successfully.");
    } else {
      return (false, "Failed to update Add Friend Achievement.");
    };
  };
  public func updateAchievementsArray(categoryId : Nat, updatedAchievement : AchievementLine) : async [AchievementLine] {
    let categoryOpt = achievementCategories.get(categoryId);
    switch (categoryOpt) {
      case (null) {
        Debug.print("Category not found");
        return []; // Return an empty array if category is not found
      };
      case (?category) {
        var updatedAchievements : [AchievementLine] = [];
        for (ach in category.achievements.vals()) {
          if (ach.id == updatedAchievement.id) {
            updatedAchievements := Array.append(updatedAchievements, [updatedAchievement]);
          } else {
            updatedAchievements := Array.append(updatedAchievements, [ach]);
          };
        };
        return updatedAchievements;
      };
    };
  };
  public func updateCategoryWithAchievement(categoryId : Nat, updatedAchievementsArray : [AchievementLine]) {
    let categoryOpt = achievementCategories.get(categoryId);
    switch (categoryOpt) {
      case (null) Debug.print("Category not found");
      case (?category) {
        let updatedCategory = {
          category with
          achievements = updatedAchievementsArray
        };

        achievementCategories.put(categoryId, updatedCategory);
      };
    };
  };
  func updateStableArrays() {
    _userProgress := Iter.toArray(userProgress.entries());
    _claimedIndividualAchievementRewards := Iter.toArray(claimedIndividualAchievementRewards.entries());
    _claimedAchievementLineRewards := Iter.toArray(claimedAchievementLineRewards.entries());
    _claimedCategoryAchievementRewards := Iter.toArray(claimedCategoryAchievementRewards.entries());
  };
  public shared func claimIndACH(id : Principal, achievementId : Nat) : async (Bool, Text) {
    let userProgressOpt = userProgress.get(id);
    switch (userProgressOpt) {
      case (null) {
        return (false, "User has no progress records.");
      };
      case (?userCategoriesList) {
        let (categoryOpt, achievementLineOpt, individualAchievementOpt) = findIndividualAchievement(userCategoriesList, achievementId);
        switch (individualAchievementOpt) {
          case (null) {
            return (false, "Individual Achievement not found");
          };
          case (?individualAchievement) {
            if (not individualAchievement.completed) {
              return (false, "Individual Achievement not completed");
            };

            let claimedRewards = switch (claimedIndividualAchievementRewards.get(id)) {
              case (null) { [] };
              case (?rewards) { rewards };
            };

            if (Array.find<Nat>(claimedRewards, func(r) { r == achievementId }) != null) {
              return (false, "Individual Achievement reward already claimed");
            };

            // Mint the rewards and collect messages
            var rewardMessage : Text = "";
            for (reward in individualAchievement.reward.vals()) {
              let (success, message) = await mintAchievementRewards(reward, id);
              if (not success) {
                return (false, message);
              };
              rewardMessage := rewardMessage # "; " # message;
            };

            // Update claimed rewards
            let updatedClaimedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewards.size() + 1);
            for (reward in claimedRewards.vals()) {
              updatedClaimedRewardsBuffer.add(reward);
            };
            updatedClaimedRewardsBuffer.add(achievementId);
            claimedIndividualAchievementRewards.put(id, Buffer.toArray(updatedClaimedRewardsBuffer));

            // Safely unwrap the optionals using a switch
            switch (achievementLineOpt) {
              case (null) {
                return (false, "Achievement Line not found");
              };
              case (?achievementLine) {
                // Update the claimed status by creating a new object with claimed = true
                let updatedIndividualAchievement : IndividualAchievement = {
                  id = individualAchievement.id;
                  achievementId = individualAchievement.achievementId;
                  name = individualAchievement.name;
                  achievementType = individualAchievement.achievementType;
                  requiredProgress = individualAchievement.requiredProgress;
                  reward = individualAchievement.reward;
                  progress = individualAchievement.progress;
                  completed = individualAchievement.completed;
                  claimed = true; // Set claimed to true
                };

                // Replace the old individual achievement with the updated one
                let updatedIndividualAchievements = Array.tabulate<IndividualAchievement>(
                  Array.size(achievementLine.individualAchievements),
                  func(i : Nat) : IndividualAchievement {
                    let indAch = achievementLine.individualAchievements[i];
                    if (indAch.id == updatedIndividualAchievement.id) {
                      updatedIndividualAchievement;
                    } else {
                      indAch;
                    };
                  },
                );

                let updatedAchievementLine : AchievementLine = {
                  id = achievementLine.id;
                  name = achievementLine.name;
                  individualAchievements = updatedIndividualAchievements;
                  categoryId = achievementLine.categoryId;
                  reward = achievementLine.reward;
                  requiredProgress = achievementLine.requiredProgress;
                  completed = achievementLine.completed;
                  progress = achievementLine.progress;
                  claimed = achievementLine.claimed;
                };

                switch (categoryOpt) {
                  case (null) {
                    return (false, "Achievement Category not found");
                  };
                  case (?category) {
                    // Update the category with the new achievement line
                    let updatedLines = Array.tabulate<AchievementLine>(
                      Array.size(category.achievements),
                      func(i : Nat) : AchievementLine {
                        let line = category.achievements[i];
                        if (line.id == updatedAchievementLine.id) {
                          updatedAchievementLine;
                        } else {
                          line;
                        };
                      },
                    );

                    let updatedCategory : AchievementCategory = {
                      id = category.id;
                      name = category.name;
                      achievements = updatedLines;
                      reward = category.reward;
                      requiredProgress = category.requiredProgress;
                      completed = category.completed;
                      progress = category.progress;
                      claimed = category.claimed;
                    };

                    // Update the user's progress
                    let updatedCategories = Array.tabulate<AchievementCategory>(
                      Array.size(userCategoriesList),
                      func(i : Nat) : AchievementCategory {
                        let cat = userCategoriesList[i];
                        if (cat.id == updatedCategory.id) {
                          updatedCategory;
                        } else {
                          cat;
                        };
                      },
                    );

                    userProgress.put(id, updatedCategories);

                    // Update stable arrays
                    updateStableArrays();

                    return (true, "Individual Achievement rewards claimed successfully. " # rewardMessage);
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  public shared (msg) func claimIndividualAchievementReward(achievementId : Nat) : async (Bool, Text) {
    let userProgressOpt = userProgress.get(msg.caller);
    switch (userProgressOpt) {
      case (null) {
        return (false, "User has no progress records.");
      };
      case (?userCategoriesList) {
        let (categoryOpt, achievementLineOpt, individualAchievementOpt) = findIndividualAchievement(userCategoriesList, achievementId);
        switch (individualAchievementOpt) {
          case (null) {
            return (false, "Individual Achievement not found");
          };
          case (?individualAchievement) {
            if (not individualAchievement.completed) {
              return (false, "Individual Achievement not completed");
            };

            let claimedRewards = switch (claimedIndividualAchievementRewards.get(msg.caller)) {
              case (null) { [] };
              case (?rewards) { rewards };
            };

            if (Array.find<Nat>(claimedRewards, func(r) { r == achievementId }) != null) {
              return (false, "Individual Achievement reward already claimed");
            };

            // Mint the rewards and collect messages
            var rewardMessage : Text = "";
            for (reward in individualAchievement.reward.vals()) {
              let (success, message) = await mintAchievementRewards(reward, msg.caller);
              if (not success) {
                return (false, message);
              };
              rewardMessage := rewardMessage # "; " # message;
            };

            // Update claimed rewards
            let updatedClaimedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewards.size() + 1);
            for (reward in claimedRewards.vals()) {
              updatedClaimedRewardsBuffer.add(reward);
            };
            updatedClaimedRewardsBuffer.add(achievementId);
            claimedIndividualAchievementRewards.put(msg.caller, Buffer.toArray(updatedClaimedRewardsBuffer));

            // Safely unwrap the optionals using a switch
            switch (achievementLineOpt) {
              case (null) {
                return (false, "Achievement Line not found");
              };
              case (?achievementLine) {
                // Update the claimed status by creating a new object with claimed = true
                let updatedIndividualAchievement : IndividualAchievement = {
                  id = individualAchievement.id;
                  achievementId = individualAchievement.achievementId;
                  name = individualAchievement.name;
                  achievementType = individualAchievement.achievementType;
                  requiredProgress = individualAchievement.requiredProgress;
                  reward = individualAchievement.reward;
                  progress = individualAchievement.progress;
                  completed = individualAchievement.completed;
                  claimed = true; // Set claimed to true
                };

                // Replace the old individual achievement with the updated one
                let updatedIndividualAchievements = Array.tabulate<IndividualAchievement>(
                  Array.size(achievementLine.individualAchievements),
                  func(i : Nat) : IndividualAchievement {
                    let indAch = achievementLine.individualAchievements[i];
                    if (indAch.id == updatedIndividualAchievement.id) {
                      updatedIndividualAchievement;
                    } else {
                      indAch;
                    };
                  },
                );

                let updatedAchievementLine : AchievementLine = {
                  id = achievementLine.id;
                  name = achievementLine.name;
                  individualAchievements = updatedIndividualAchievements;
                  categoryId = achievementLine.categoryId;
                  reward = achievementLine.reward;
                  requiredProgress = achievementLine.requiredProgress;
                  completed = achievementLine.completed;
                  progress = achievementLine.progress;
                  claimed = achievementLine.claimed;
                };

                switch (categoryOpt) {
                  case (null) {
                    return (false, "Achievement Category not found");
                  };
                  case (?category) {
                    // Update the category with the new achievement line
                    let updatedLines = Array.tabulate<AchievementLine>(
                      Array.size(category.achievements),
                      func(i : Nat) : AchievementLine {
                        let line = category.achievements[i];
                        if (line.id == updatedAchievementLine.id) {
                          updatedAchievementLine;
                        } else {
                          line;
                        };
                      },
                    );

                    let updatedCategory : AchievementCategory = {
                      id = category.id;
                      name = category.name;
                      achievements = updatedLines;
                      reward = category.reward;
                      requiredProgress = category.requiredProgress;
                      completed = category.completed;
                      progress = category.progress;
                      claimed = category.claimed;
                    };

                    // Update the user's progress
                    let updatedCategories = Array.tabulate<AchievementCategory>(
                      Array.size(userCategoriesList),
                      func(i : Nat) : AchievementCategory {
                        let cat = userCategoriesList[i];
                        if (cat.id == updatedCategory.id) {
                          updatedCategory;
                        } else {
                          cat;
                        };
                      },
                    );

                    userProgress.put(msg.caller, updatedCategories);

                    // Update stable arrays
                    updateStableArrays();

                    return (true, "Individual Achievement rewards claimed successfully. " # rewardMessage);
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  public shared (msg) func claimAchievementLineReward(achievementId : Nat) : async (Bool, Text) {
    let userProgressOpt = userProgress.get(msg.caller);
    switch (userProgressOpt) {
      case (null) {
        return (false, "User has no progress records.");
      };
      case (?userCategoriesList) {
        for (category in userCategoriesList.vals()) {
          for (achievementLineOpt in category.achievements.vals()) {
            switch (achievementLineOpt) {
              case (achievementLine) {
                if (achievementLine.id == achievementId) {
                  if (not achievementLine.completed) {
                    return (false, "Achievement Line not completed");
                  };

                  let claimedRewards = switch (claimedAchievementLineRewards.get(msg.caller)) {
                    case (null) { [] };
                    case (?rewards) { rewards };
                  };

                  if (Array.find<Nat>(claimedRewards, func(r) { r == achievementId }) != null) {
                    return (false, "Achievement Line reward already claimed");
                  };

                  // Mint the rewards and collect messages
                  var rewardMessage : Text = "";
                  for (reward in achievementLine.reward.vals()) {
                    let (success, message) = await mintAchievementRewards(reward, msg.caller);
                    if (not success) {
                      return (false, message);
                    };
                    rewardMessage := rewardMessage # "; " # message;
                  };

                  // Update claimed rewards
                  let updatedClaimedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewards.size() + 1);
                  for (reward in claimedRewards.vals()) {
                    updatedClaimedRewardsBuffer.add(reward);
                  };
                  updatedClaimedRewardsBuffer.add(achievementId);
                  claimedAchievementLineRewards.put(msg.caller, Buffer.toArray(updatedClaimedRewardsBuffer));

                  // Update the claimed status by creating a new object with claimed = true
                  let updatedAchievementLine : AchievementLine = {
                    id = achievementLine.id;
                    name = achievementLine.name;
                    individualAchievements = achievementLine.individualAchievements;
                    categoryId = achievementLine.categoryId;
                    reward = achievementLine.reward;
                    requiredProgress = achievementLine.requiredProgress;
                    completed = achievementLine.completed;
                    progress = achievementLine.progress;
                    claimed = true; // Set claimed to true
                  };

                  let updatedLines = Array.tabulate<AchievementLine>(
                    Array.size(category.achievements),
                    func(i : Nat) : AchievementLine {
                      let line = category.achievements[i];
                      if (line.id == updatedAchievementLine.id) {
                        updatedAchievementLine;
                      } else {
                        line;
                      };
                    },
                  );

                  let updatedCategory : AchievementCategory = {
                    id = category.id;
                    name = category.name;
                    achievements = updatedLines;
                    reward = category.reward;
                    requiredProgress = category.requiredProgress;
                    completed = category.completed;
                    progress = category.progress;
                    claimed = category.claimed;
                  };

                  let updatedCategories = Array.tabulate<AchievementCategory>(
                    Array.size(userCategoriesList),
                    func(i : Nat) : AchievementCategory {
                      let cat = userCategoriesList[i];
                      if (cat.id == updatedCategory.id) {
                        updatedCategory;
                      } else {
                        cat;
                      };
                    },
                  );

                  userProgress.put(msg.caller, updatedCategories);

                  // Update stable arrays
                  updateStableArrays();

                  return (true, "Achievement Line rewards claimed successfully. " # rewardMessage);
                };
              };
            };
          };
        };
        return (false, "Achievement Line not found");
      };
    };
  };
  public shared (msg) func claimCategoryAchievementReward(categoryId : Nat) : async (Bool, Text) {
    let userProgressOpt = userProgress.get(msg.caller);
    switch (userProgressOpt) {
      case (null) {
        return (false, "User has no progress records.");
      };
      case (?userCategoriesList) {
        for (categoryOpt in userCategoriesList.vals()) {
          switch (categoryOpt) {
            case (category) {
              if (category.id == categoryId) {
                if (not category.completed) {
                  return (false, "Achievement Category not completed");
                };

                let claimedRewards = switch (claimedCategoryAchievementRewards.get(msg.caller)) {
                  case (null) { [] };
                  case (?rewards) { rewards };
                };

                if (Array.find<Nat>(claimedRewards, func(r) { r == categoryId }) != null) {
                  return (false, "Achievement Category reward already claimed");
                };

                // Mint the rewards and collect messages
                var rewardMessage : Text = "";
                for (reward in category.reward.vals()) {
                  let (success, message) = await mintAchievementRewards(reward, msg.caller);
                  if (not success) {
                    return (false, message);
                  };
                  rewardMessage := rewardMessage # "; " # message;
                };

                // Update claimed rewards
                let updatedClaimedRewardsBuffer = Buffer.Buffer<Nat>(claimedRewards.size() + 1);
                for (reward in claimedRewards.vals()) {
                  updatedClaimedRewardsBuffer.add(reward);
                };
                updatedClaimedRewardsBuffer.add(categoryId);
                claimedCategoryAchievementRewards.put(msg.caller, Buffer.toArray(updatedClaimedRewardsBuffer));

                // Update the claimed status by creating a new object with claimed = true
                let updatedCategory : AchievementCategory = {
                  id = category.id;
                  name = category.name;
                  achievements = category.achievements;
                  reward = category.reward;
                  requiredProgress = category.requiredProgress;
                  completed = category.completed;
                  progress = category.progress;
                  claimed = true; // Set claimed to true
                };

                let updatedCategories = Array.tabulate<AchievementCategory>(
                  Array.size(userCategoriesList),
                  func(i : Nat) : AchievementCategory {
                    let cat = userCategoriesList[i];
                    if (cat.id == updatedCategory.id) {
                      updatedCategory;
                    } else {
                      cat;
                    };
                  },
                );

                userProgress.put(msg.caller, updatedCategories);

                // Update stable arrays
                updateStableArrays();

                return (true, "Achievement Category rewards claimed successfully. " # rewardMessage);
              };
            };
          };
        };
        return (false, "Achievement Category not found");
      };
    };
  };
  public shared func mintAchievementRewards(reward : AchievementReward, caller : Types.PlayerId) : async (Bool, Text) {
    switch (reward.rewardType) {
      case (#Stardust) {
        let mintArgs : ICRC1.Mint = {
          to = { owner = caller; subaccount = null };
          amount = reward.amount;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        };
        let mintResult = await mint(mintArgs);
        switch (mintResult) {
          case (#Ok(_transactionID)) {
            await updateMintedStardust(caller, reward.amount);
            return (true, "Stardust minted successfully. Quantity: " # Nat.toText(reward.amount));
          };
          case (#Err(_error)) {
            return (false, "Minting stardust failed");
          };
        };
      };
      case (#Chest) {
        let (success, message) = await mintChest(caller, reward.amount);
        if (success) {
          return (true, "Chest minted successfully with Rarity " # Nat.toText(reward.amount));
        };
        return (success, message);
      };
      case (#NFT) {
        let nftTemplateId = reward.amount; // Use the reward amount as the template ID
        let mintResult = await mintUnit(nftTemplateId, caller); // Pass caller to mint the NFT for the player
        switch (mintResult) {
          case (#Ok(tokenId)) {
            return (true, " NFT minted successfully with Token ID: " # Nat.toText(tokenId));
          };
          case (#Err(_error)) {
            return (false, "Minting Unit NFT failed");
          };
        };
      };
      case (#Title) {
        let titleId = reward.amount;
        let userTitles = switch (availableTitles.get(caller)) {
          case (null) { [] };
          case (?titles) { titles };
        };

        if (Array.find<Nat>(userTitles, func(t) { t == titleId }) == null) {
          let updatedTitlesBuffer = Buffer.Buffer<Nat>(userTitles.size() + 1);
          for (titleId in userTitles.vals()) {
            updatedTitlesBuffer.add(titleId);
          };
          updatedTitlesBuffer.add(titleId);
          availableTitles.put(caller, Buffer.toArray(updatedTitlesBuffer));
          return (true, "Title ID earned: " # Nat.toText(titleId));
        };
        return (false, "Title already exists for the user.");
      };
      case (#Avatar) {
        let avatarId = reward.amount;
        let userAvatars = switch (availableAvatars.get(caller)) {
          case (null) { [] };
          case (?avatars) { avatars };
        };

        if (Array.find<Nat>(userAvatars, func(a) { a == avatarId }) == null) {
          let updatedAvatarsBuffer = Buffer.Buffer<Nat>(userAvatars.size() + 1);
          for (avatarId in userAvatars.vals()) {
            updatedAvatarsBuffer.add(avatarId);
          };
          updatedAvatarsBuffer.add(avatarId);
          availableAvatars.put(caller, Buffer.toArray(updatedAvatarsBuffer));
          return (true, "Avatar ID earned: " # Nat.toText(avatarId));
        };
        return (false, "Avatar already exists for the user.");
      };
      case (#XP) {
        var playerStatsOpt = playerGamesStats.get(caller);
        if (playerStatsOpt == null) {
          ignore await _initializeNewPlayerStats(caller);
          playerStatsOpt := playerGamesStats.get(caller);
        };

        switch (playerStatsOpt) {
          case (null) {
            return (false, "Failed to initialize player stats.");
          };
          case (?stats) {
            let updatedStats = {
              stats with totalXpEarned = stats.totalXpEarned + reward.amount
            };
            playerGamesStats.put(caller, updatedStats);

            let (_, _) = await updatePlayerLevel(caller);
            return (true, "XP earned: " # Nat.toText(reward.amount));
          };
        };
      };
      case (#Multiplier) {

        return (false, "not implemented");
      };
    };
  };
  // #endregion

  //#region |Views|
  /**
  public type TopView = {
    referralsTop : [ReferralsTop];
    eloTop : [ELOTop];
    nftTop : [NFTTop];
    levelTop : [LevelTop];
    achTop : [AchievementsTop];
  };

  public shared func get_tops() : async (TopView) {
    {
      referralsTop = await getTopReferrals(0);
      eloTop = await getTopELO(0);
      nftTop = await getTopNFT(0);
      levelTop = await getTopLevel(0);
      achTop = await getTopAchievements(0);
    };
  };
  */
  public shared ({ caller }) func get_achievements() : async (
    [AchievementCategory],
    [AchievementLine],
    [IndividualAchievement],
  ) {

    let data = await getUserAchievements(caller);
    var categories : [AchievementCategory] = [];
    var lines : [AchievementLine] = [];
    var individuals : [IndividualAchievement] = [];

    for (category in data.vals()) {
      categories := Array.append(categories, [category]);
      for (line in category.achievements.vals()) {
        lines := Array.append(lines, [line]);
        for (achievement in line.individualAchievements.vals()) {
          individuals := Array.append(individuals, [achievement]);
        };
      };
    };
    (categories, lines, individuals);
  };

  public shared ({ caller }) func getAchievementsView() : async (
    [AchievementCategory],
    [AchievementLine],
    [IndividualAchievement],
  ) {
    let data = await getUserAchievements(caller);
    var categories : [AchievementCategory] = [];
    var lines : [AchievementLine] = [];
    var individuals : [IndividualAchievement] = [];
    for (category in data.vals()) {
      categories := Array.append(categories, [category]);
      for (line in category.achievements.vals()) {
        lines := Array.append(lines, [line]);
        for (achievement in line.individualAchievements.vals()) {
          individuals := Array.append(individuals, [achievement]);
        };
      };
    };
    (categories, lines, individuals);
  };

  // #endregion

};