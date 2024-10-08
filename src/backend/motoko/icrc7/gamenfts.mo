import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Types "./types";
import Utils "./utils";

shared actor class GameNFTs(collectionOwner: Types.Account, init: Types.CollectionInitArgs) = Self {
  private stable var owner: Types.Account = collectionOwner;
  
  private stable var name: Text = init.name;
  private stable var symbol: Text = init.symbol;
  private stable var royalties: ?Nat16 = init.royalties;
  private stable var royaltyRecipient: ?Types.Account = init.royaltyRecipient;
  private stable var description: ?Text = init.description;
  private stable var image: ?Blob = init.image;
  private stable var supplyCap: ?Nat = init.supplyCap;
  private stable var totalSupply: Nat = 0;
  private stable var transferSequentialIndex: Nat = 0;
  private stable var approvalSequentialIndex: Nat = 0;
  private stable var transactionSequentialIndex: Nat = 0;

  public type Metadata = Types.Metadata;
  public type GeneralMetadata = Types.GeneralMetadata;
  public type BasicMetadata = Types.BasicMetadata;
  public type Category = Types.Category;
  public type CharacterMetadata = Types.CharacterMetadata;
  public type Unit = Types.Unit;
  public type SpaceshipMetadata = Types.SpaceshipMetadata;
  public type StationMetadata = Types.StationMetadata;
  public type WeaponMetadata = Types.WeaponMetadata;
  public type AvatarMetadata = Types.AvatarMetadata;
  public type ChestMetadata = Types.ChestMetadata;
  public type TrophyMetadata = Types.TrophyMetadata;
  public type SkinMetadata = Types.SkinMetadata;
  public type SoulMetadata = Types.SoulMetadata;
  public type SkillMetadata = Types.SkillMetadata;
  public type ShieldMetadata = Types.ShieldMetadata;
  public type EvasionMetadata = Types.EvasionMetadata;
  public type CriticalStrikeMetadata = Types.CriticalStrikeMetadata;
  public type Faction = Types.Faction;

  // https://forum.dfinity.org/t/is-there-any-address-0-equivalent-at-dfinity-motoko/5445/3
  private var NULL_PRINCIPAL: Principal = Principal.fromText("aaaaa-aa");
  private var PERMITTED_DRIFT : Nat64 = 2 * 60 * 1_000_000_000; // 2 minutes in nanoseconds
  private var TX_WINDOW : Nat64 = 24 * 60 * 60 * 1_000_000_000; // 24 hours in nanoseconds

  private stable var _cosmicraftsPrincipal : Principal = Principal.fromActor(actor("fdaor-cqaaa-aaaao-ai7nq-cai"));
  //  private stable var _cosmicraftsPrincipal : Principal = Principal.fromActor(actor("bkyz2-fmaaa-aaaaa-qaaaq-cai"));


  private stable var tokens: Trie<Types.TokenId, Types.TokenMetadata> = Trie.empty(); 
  //owner Trie: use of Text insted of Account to improve performanances in lookup
  private stable var owners: Trie<Text, [Types.TokenId]> = Trie.empty(); //fast lookup
  //balances Trie: use of Text insted of Account to improve performanances in lookup (could also retrieve this from owners[account].size())
  private stable var balances: Trie<Text, Nat> = Trie.empty(); //fast lookup
  
  //approvals by account Trie
  private stable var tokenApprovals: Trie<Types.TokenId, [Types.TokenApproval]> = Trie.empty();
  //approvals by operator Trie: use of Text insted of Account to improve performanances in lookup
  private stable var operatorApprovals: Trie<Text, [Types.OperatorApproval]> = Trie.empty();

  //transactions Trie
  private stable var transactions: Trie<Types.TransactionId, Types.Transaction> = Trie.empty(); 
  //transactions by operator Trie: use of Text insted of Account to improve performanances in lookup
  private stable var transactionsByAccount: Trie<Text, [Types.TransactionId]> = Trie.empty(); 

  // we do this to have shorter type names and thus better readibility
  // see https://internetcomputer.org/docs/current/motoko/main/base/Trie
  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;

  // we have to provide `put`, `get` and `remove` with
  // a record of type `Key<K> = { hash: Hash.Hash; key: K }`;
  // thus we define the following function that takes a value of type `K`
  // (in this case `Text`) and returns a `Key<K>` record.
  // see https://internetcomputer.org/docs/current/motoko/main/base/Trie
  private func _keyFromTokenId(t: Types.TokenId): Key<Types.TokenId> {{ hash = Utils._natHash(t); key = t }};
  private func _keyFromText(t: Text): Key<Text> { { hash = Text.hash t; key = t } };
  private func _keyFromTransactionId(t: Types.TransactionId): Key<Types.TransactionId> { { hash = Utils._natHash(t); key = t } };

  public shared query func icrc7_collection_metadata(): async Types.CollectionMetadata {
    return {
      name = name;
      symbol = symbol;
      royalties = royalties;
      royaltyRecipient = royaltyRecipient;
      description = description;
      image = image;
      totalSupply = totalSupply;
      supplyCap = supplyCap;
    }
  };

  public shared query func icrc7_name(): async Text {
    return name;
  };

  public shared query func icrc7_symbol(): async Text {
    return symbol;
  };

  public shared query func icrc7_royalties(): async ?Nat16 {
    return royalties;
  };

  public shared query func icrc7_royalty_recipient(): async ?Types.Account {
    return royaltyRecipient;
  };

  public shared query func icrc7_description(): async ?Text {
    return description;
  };

  public shared query func icrc7_image(): async ?Blob {
    return image;
  };

  public shared query func icrc7_total_supply(): async Nat {
    return totalSupply;
  };

  public shared query func icrc7_supply_cap(): async ?Nat {
    return supplyCap;
  };

  public shared query func icrc7_metadata(tokenId: Types.TokenId): async Types.MetadataResult {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?_elem) {
        return #Ok(_elem.metadata);
      }
    };
  };

  public shared query func icrc7_owner_of(tokenId: Types.TokenId): async Types.OwnerResult {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return #Err(#InvalidTokenId);
      };
      case (?_elem) {
        return #Ok(_elem.owner);
      }
    };
  };

  public shared query func icrc7_balance_of(account: Types.Account): async Types.BalanceResult {
    let acceptedAccount: Types.Account = _acceptAccount(account);
    let accountText: Text = Utils.accountToText(acceptedAccount);
    let item = Trie.get(balances, _keyFromText accountText, Text.equal);
    switch (item) {
      case null {
        return #Ok(0);
      };
      case (?_elem) {
        return #Ok(_elem);
      }
    };
  };

  public shared query func icrc7_tokens_of(account: Types.Account): async Types.TokensOfResult {
    let acceptedAccount: Types.Account = _acceptAccount(account);
    let accountText: Text = Utils.accountToText(acceptedAccount);
    let item = Trie.get(owners, _keyFromText accountText, Text.equal);
    switch (item) {
      case null {
        return #Ok([]);
      };
      case (?_elem) {
        return #Ok(_elem);
      }
    };
  };

  public shared({ caller }) func icrc7_transfer(transferArgs: Types.TransferArgs): async Types.TransferReceipt {
    let now = Nat64.fromIntWrap(Time.now());

    let callerSubaccount: Types.Subaccount = switch(transferArgs.spender_subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };
    let acceptedCaller: Types.Account = _acceptAccount({owner= caller; subaccount=?callerSubaccount});

    let acceptedFrom: Types.Account = switch(transferArgs.from) {
      case null acceptedCaller;
      case (?_elem) _acceptAccount(_elem);
    };

    let acceptedTo: Types.Account = _acceptAccount(transferArgs.to);

    if (transferArgs.created_at_time != null) {
      if (Nat64.less(Utils.nullishCoalescing<Nat64>(transferArgs.created_at_time, 0), now - TX_WINDOW - PERMITTED_DRIFT)) {
        return #Err(#TooOld());
      };

      if (Nat64.greater(Utils.nullishCoalescing<Nat64>(transferArgs.created_at_time, 0), now + PERMITTED_DRIFT)) {
        return #Err(#CreatedInFuture({
          ledger_time = now;
        }));
      };

    };

    if (transferArgs.token_ids.size() == 0) {
      return #Err(#GenericError({
        error_code = _transferErrorCodeToCode(#EmptyTokenIds); 
        message = _transferErrorCodeToText(#EmptyTokenIds);
      }));
    };

    //no duplicates in token ids are allowed
    let duplicatesCheckHashMap = HashMap.HashMap<Types.TokenId, Bool>(5, Nat.equal, Utils._natHash);
    for (tokenId in transferArgs.token_ids.vals()) {
      let duplicateCheck = duplicatesCheckHashMap.get(tokenId);
      if (duplicateCheck != null) {
        return #Err(#GenericError({
          error_code = _transferErrorCodeToCode(#DuplicateInTokenIds); 
          message = _transferErrorCodeToText(#DuplicateInTokenIds);
        }));
      }
    };

    //by default is_atomic is true
    let isAtomic: Bool = Utils.nullishCoalescing<Bool>(transferArgs.is_atomic, true);
    
    //? should be added here deduplication?

    if (isAtomic) {
      let errors = Buffer.Buffer<Types.TransferError>(0); // Creates a new Buffer
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
      }
    };

    let transferredTokenIds = Buffer.Buffer<Types.TokenId>(0); //Creates a new Buffer of transferred tokens
    let errors = Buffer.Buffer<Types.TransferError>(0); // Creates a new Buffer
    for (tokenId in transferArgs.token_ids.vals()) {
      let transferResult = _singleTransfer(?acceptedCaller, acceptedFrom, acceptedTo, tokenId, false, now);
      switch (transferResult) {
          case null transferredTokenIds.add(tokenId);
          case (?_elem) errors.add(_elem);
        };
    };

    if (isAtomic) {
      assert(errors.size() == 0);
    };

    //? it's not clear if return the Err or Ok
    if (errors.size() > 0) {
      return #Err(errors.get(0));
    };

    let transferId: Nat = transferSequentialIndex;
    _incrementTransferIndex();

    let _transaction: Types.Transaction = _addTransaction(#icrc7_transfer, now, ?Buffer.toArray(transferredTokenIds), ?acceptedTo, ?acceptedFrom, ?acceptedCaller, transferArgs.memo, transferArgs.created_at_time, null);

    return #Ok(transferId);
  };

  public shared({ caller }) func icrc7_approve(approvalArgs: Types.ApprovalArgs): async Types.ApprovalReceipt {
    let now = Nat64.fromIntWrap(Time.now());

    let callerSubaccount: Types.Subaccount = switch(approvalArgs.from_subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };
    let acceptedFrom: Types.Account = _acceptAccount({owner= caller; subaccount=?callerSubaccount});

    let acceptedSpender: Types.Account = _acceptAccount(approvalArgs.spender);

    if (Utils.compareAccounts(acceptedFrom, acceptedSpender) == #equal) {
      return #Err(#GenericError({
        error_code = _approveErrorCodeToCode(#SelfApproval); 
        message = _approveErrorCodeToText(#SelfApproval);
      }));
    };

    if (approvalArgs.created_at_time != null) {
      if (Nat64.less(Utils.nullishCoalescing<Nat64>(approvalArgs.created_at_time, 0), now - TX_WINDOW - PERMITTED_DRIFT)) {
        return #Err(#TooOld());
      };
    };

    let tokenIds: [Types.TokenId] = switch(approvalArgs.token_ids) {
      case null [];
      case (?_elem) _elem;
    };

    let unauthorizedTokenIds = Buffer.Buffer<Types.ApprovalId>(0);

    for (tokenId in tokenIds.vals()) {
      if (_exists(tokenId) == false) {
        unauthorizedTokenIds.add(tokenId);
      } else if (_isOwner(acceptedFrom, tokenId) == false) { //check if the from is owner of approved token
        unauthorizedTokenIds.add(tokenId);
      };
    };

    if (unauthorizedTokenIds.size() > 0) {
      return #Err(#Unauthorized({
        token_ids = Buffer.toArray(unauthorizedTokenIds);
      }));
    };

    let approvalId: Types.ApprovalId = _createApproval(acceptedFrom, acceptedSpender, tokenIds, approvalArgs.expires_at, approvalArgs.memo, approvalArgs.created_at_time);
    
    let _transaction: Types.Transaction = _addTransaction(#icrc7_approve, now, approvalArgs.token_ids, null, ?acceptedFrom, ?acceptedSpender, approvalArgs.memo, approvalArgs.created_at_time, approvalArgs.expires_at);

    return #Ok(approvalId);
  };

  public shared query func icrc7_supported_standards(): async [Types.SupportedStandard] {
    return [{ name = "ICRC-7"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-7" }];
  };

  public shared query func get_collection_owner(): async Types.Account {
    return owner;
  };

  public shared({ caller }) func mint(mintArgs: Types.MintArgs): async Types.MintReceipt {
    let now = Nat64.fromIntWrap(Time.now());
    let acceptedTo: Types.Account = _acceptAccount(mintArgs.to);

    //todo add a more complex roles management
    if (Principal.notEqual(caller, owner.owner) and Principal.notEqual(caller, _cosmicraftsPrincipal) ) {
      return #Err(#Unauthorized);
    };

    //check on supply cap overflow
    if (supplyCap != null) {
      let _supplyCap: Nat = Utils.nullishCoalescing<Nat>(supplyCap, 0);
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
    let newToken: Types.TokenMetadata = {
      tokenId = mintArgs.token_id;
      owner = acceptedTo;
      metadata = mintArgs.metadata;
    };

    //update the token metadata
    let tokenId : Types.TokenId = mintArgs.token_id;
    tokens := Trie.put(tokens, _keyFromTokenId tokenId, Nat.equal, newToken).0;

    _addTokenToOwners(acceptedTo, mintArgs.token_id);

    _incrementBalance(acceptedTo);

    _incrementTotalSupply(1);

    let _transaction: Types.Transaction = _addTransaction(#mint, now, ?[mintArgs.token_id], ?acceptedTo, null, null, null, null, null);

    return #Ok(mintArgs.token_id);
  };

  public func get_transactions(getTransactionsArgs: Types.GetTransactionsArgs): async Types.GetTransactionsResult {
    let result : Types.GetTransactionsResult = switch (getTransactionsArgs.account) {
      case null {
        let allTransactions: [Types.Transaction] = Trie.toArray<Types.TransactionId, Types.Transaction, Types.Transaction>(
          transactions,
          func (k, v) = v
        );

        let checkedOffset = Nat.min(Array.size(allTransactions), getTransactionsArgs.offset);
        let length = Nat.min(getTransactionsArgs.limit, Array.size(allTransactions) - checkedOffset);
        let subArray: [Types.Transaction] = Array.subArray<Types.Transaction>(allTransactions, checkedOffset, length);
        {
          total = Array.size(allTransactions);
          transactions = subArray;
        };
      };
      case (?_elem) {
        let acceptedAccount: Types.Account = _acceptAccount(_elem);
        let accountText: Text = Utils.accountToText(acceptedAccount);
        let accountTransactions: [Types.TransactionId] = Utils.nullishCoalescing<[Types.TransactionId]>(Trie.get(transactionsByAccount, _keyFromText accountText, Text.equal), []);
        let reversedAccountTransactions: [Types.TransactionId] = Array.reverse(accountTransactions);

        let checkedOffset = Nat.min(Array.size(reversedAccountTransactions), getTransactionsArgs.offset);
        let length = Nat.min(getTransactionsArgs.limit, Array.size(reversedAccountTransactions) - checkedOffset);
        let subArray: [Types.TransactionId] = Array.subArray<Types.TransactionId>(reversedAccountTransactions, checkedOffset, length);
        
        let returnedTransactions = Buffer.Buffer<Types.Transaction>(0);

        for (transactionId in subArray.vals()) {
          let transaction = Trie.get(transactions, _keyFromTransactionId transactionId, Nat.equal);
          switch(transaction) {
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

  private func _addTokenToOwners(account: Types.Account, tokenId: Types.TokenId) {
    //get Textual rapresentation of the Account
    let textAccount: Text = Utils.accountToText(account);

    //find the tokens owned by an account, in order to add the new one
    let newOwners = Utils.nullishCoalescing<[Types.TokenId]>(Trie.get(owners, _keyFromText textAccount, Text.equal), []);

    //add the token id
    owners := Trie.put(owners, _keyFromText textAccount, Text.equal, Utils.pushIntoArray<Types.TokenId>(tokenId, newOwners)).0;
  };

  private func _removeTokenFromOwners(account: Types.Account, tokenId: Types.TokenId) {
    //get Textual rapresentation of the Account
    let textAccount: Text = Utils.accountToText(account);

    //find the tokens owned by an account, in order to add the new one
    let newOwners = Utils.nullishCoalescing<[Types.TokenId]>(Trie.get(owners, _keyFromText textAccount, Text.equal), []);

    let updated: [Types.TokenId] = Array.filter<Types.TokenId>(newOwners, func x = x != tokenId);

    //add the token id
    owners := Trie.put(owners, _keyFromText textAccount, Text.equal, updated).0;
  };

  private func _incrementBalance(account: Types.Account) {
    //get Textual rapresentation of the Account
    let textAccount: Text = Utils.accountToText(account);

    //find the balance of an account, in order to increment
    let balanceResult = Trie.get(balances, _keyFromText textAccount, Text.equal);

    let actualBalance: Nat = switch(balanceResult) {
      case null 0;
      case (?_elem) _elem;
    };

    //update the balance
    balances := Trie.put(balances, _keyFromText textAccount, Text.equal, actualBalance + 1).0;
  };

  private func _decrementBalance(account: Types.Account) {
      // Get textual representation of the account
      let textAccount: Text = Utils.accountToText(account);

      // Find the balance of an account, in order to decrement
      let balanceResult = Trie.get(balances, _keyFromText textAccount, Text.equal);

      switch balanceResult {
          case null { /* Balance not found, nothing to decrement */ };
          case (?actualBalance) {
              if (Nat.greater(actualBalance, 0)) {
                  balances := Trie.put(balances, _keyFromText textAccount, Text.equal, Nat.sub(actualBalance, 1)).0;
              }
          }
      }
  };

  //increment the total supply
  private func _incrementTotalSupply(quantity: Nat) {
    totalSupply := totalSupply + quantity;
  };

  private func _singleTransfer(caller: ?Types.Account, from: Types.Account, to: Types.Account, tokenId: Types.TokenId, dryRun: Bool, now: Nat64): ?Types.TransferError {
    //check if token exists
    if (_exists(tokenId) == false) {
      return ?#Unauthorized({
        token_ids = [tokenId];
      });
    };

    //check if caller is owner or approved to transferred token
    switch(caller) {
      case null {};
      case (?_elem) {
        if (_isApprovedOrOwner(_elem, tokenId, now) == false) {
          return ?#Unauthorized({
            token_ids = [tokenId];
          });
        };
      }
    };

    //check if the from is owner of transferred token
    if (_isOwner(from, tokenId) == false) {
      return ?#Unauthorized({
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

private func _updateToken(tokenId: Types.TokenId, newOwner: ?Types.Account, newMetadata: ?Types.Metadata) {
    let item = Trie.get(tokens, _keyFromTokenId(tokenId), Nat.equal);

    switch (item) {
        case null {
            return;
        };
        case (?_elem) {
            // Update owner
            let newToken: Types.TokenMetadata = {
                tokenId = _elem.tokenId;
                owner = Utils.nullishCoalescing<Types.Account>(newOwner, _elem.owner);
                metadata = Utils.nullishCoalescing<Types.Metadata>(newMetadata, _elem.metadata);
            };

            // Update the token metadata
            tokens := Trie.put(tokens, _keyFromTokenId(tokenId), Nat.equal, newToken).0;
            return;
        }
    };
};


  private func _isApprovedOrOwner(spender: Types.Account, tokenId: Types.TokenId, now: Nat64): Bool {
    return _isOwner(spender, tokenId) or _isApproved(spender, tokenId, now);
  };

  private func _isOwner(spender: Types.Account, tokenId: Types.TokenId): Bool {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch (item) {
      case null {
        return false;
      };
      case (?_elem) {
        return Utils.compareAccounts(spender, _elem.owner) == #equal;
      }
    };
  };

  private func _isApproved(spender: Types.Account, tokenId: Types.TokenId, now: Nat64): Bool {
    let item = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);

    switch (item) {
      case null {
        return false;
      };
      case (?_elem) {
        let ownerToText: Text = Utils.accountToText(_elem.owner);
        let approvalsByThisOperator: [Types.OperatorApproval] = Utils.nullishCoalescing<[Types.OperatorApproval]>(Trie.get(operatorApprovals, _keyFromText ownerToText, Text.equal), []);

        let approvalForThisSpender = Array.find<Types.OperatorApproval>(approvalsByThisOperator, func x = Utils.compareAccounts(spender, x.spender) == #equal and (x.expires_at == null or Nat64.greater(Utils.nullishCoalescing<Nat64>(x.expires_at, 0), now)));

        switch (approvalForThisSpender) {
          case (?_foundOperatorApproval) return true;
          case null {
            let approvalsForThisToken: [Types.TokenApproval] = Utils.nullishCoalescing<[Types.TokenApproval]>(Trie.get(tokenApprovals, _keyFromTokenId tokenId, Nat.equal), []);
            let approvalForThisToken = Array.find<Types.TokenApproval>(approvalsForThisToken, func x = Utils.compareAccounts(spender, x.spender) == #equal and (x.expires_at == null or Nat64.greater(Utils.nullishCoalescing<Nat64>(x.expires_at, 0), now)));
            switch (approvalForThisToken) { 
              case (?_foundTokenApproval) return true;
              case null return false;
            }

          };
        };

        return false;
      }
    };
  };

  private func _exists(tokenId: Types.TokenId): Bool {
    let tokensResult = Trie.get(tokens, _keyFromTokenId tokenId, Nat.equal);
    switch(tokensResult) {
      case null return false;
      case (?_elem) return true;
    };
  };

  private func _incrementTransferIndex() {
    transferSequentialIndex := transferSequentialIndex + 1;
  };

  private func _getDefaultSubaccount(): Blob {
    return Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
  };

  private func _acceptAccount(account: Types.Account): Types.Account {
    let effectiveSubaccount: Blob = switch (account.subaccount) {
      case null _getDefaultSubaccount();
      case (?_elem) _elem;
    };

    return {
      owner = account.owner;
      subaccount = ?effectiveSubaccount;
    };
  };

  private func _transferErrorCodeToCode(d: Types.TransferErrorCode): Nat {
    switch d {
      case (#EmptyTokenIds) 0;
      case (#DuplicateInTokenIds) 1;
    };
  };

  private func _transferErrorCodeToText(d: Types.TransferErrorCode): Text {
    switch d {
      case (#EmptyTokenIds) "Empty Token Ids";
      case (#DuplicateInTokenIds) "Duplicates in Token Ids array";
    };
  };

  private func _approveErrorCodeToCode(d: Types.ApproveErrorCode): Nat {
    switch d {
      case (#SelfApproval) 0;
    };
  };

  private func _approveErrorCodeToText(d: Types.ApproveErrorCode): Text {
    switch d {
      case (#SelfApproval) "No Self Approvals";
    };
  };

  //if token_ids is empty, approve entire collection
  private func _createApproval(from: Types.Account, spender: Types.Account, tokenIds: [Types.TokenId], expiresAt: ?Nat64, memo: ?Blob, createdAtTime: ?Nat64) : Types.ApprovalId {

      // Handle approvals
      if (tokenIds.size() == 0) {
            //get Textual rapresentation of the Account
            let fromTextAccount: Text = Utils.accountToText(from);
            let approvalsByThisOperator: [Types.OperatorApproval] = Utils.nullishCoalescing<[Types.OperatorApproval]>(Trie.get(operatorApprovals, _keyFromText fromTextAccount, Text.equal), []);
            let newApproval: Types.OperatorApproval = {
                  spender = spender;
                  memo = memo;
                  expires_at = expiresAt;
                  created_at_time = createdAtTime;
            };

            //add the updated approval
            operatorApprovals := Trie.put(operatorApprovals, _keyFromText fromTextAccount, Text.equal, Utils.pushIntoArray<Types.OperatorApproval>(newApproval, approvalsByThisOperator)).0;
      } else {
            for (tokenId in tokenIds.vals()) {
                  let approvalsForThisToken: [Types.TokenApproval] = Utils.nullishCoalescing<[Types.TokenApproval]>(Trie.get(tokenApprovals, _keyFromTokenId tokenId, Nat.equal), []);
                  let newApproval: Types.TokenApproval = {
                  spender = spender;
                  memo = memo;
                  expires_at = expiresAt;
                  created_at_time = createdAtTime;
                  };
                  //add the updated approval
                  tokenApprovals := Trie.put(tokenApprovals, _keyFromTokenId tokenId, Nat.equal, Utils.pushIntoArray<Types.TokenApproval>(newApproval, approvalsForThisToken)).0;
            };
      };

      let approvalId: Types.ApprovalId = approvalSequentialIndex;
      _incrementApprovalIndex();

      return approvalId;
      };

  private func _incrementApprovalIndex() {
    approvalSequentialIndex := approvalSequentialIndex + 1;
  };

  private func _deleteAllTokenApprovals(tokenId: Types.TokenId) {
    tokenApprovals := Trie.remove(tokenApprovals, _keyFromTokenId tokenId, Nat.equal).0;
  };

  private func _addTransaction(kind: {#mint; #icrc7_transfer; #icrc7_approve; #upgrade}, timestamp: Nat64, tokenIds: ?[Types.TokenId], to: ?Types.Account, from: ?Types.Account, spender: ?Types.Account, memo: ?Blob, createdAtTime: ?Nat64, expiresAt: ?Nat64) : Types.Transaction {
    let transactionId: Types.TransactionId = transactionSequentialIndex;
    _incrementTransactionIndex();

    let acceptedTo = Utils.nullishCoalescing<Types.Account>(to, _acceptAccount({owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount()}));
    let acceptedFrom = Utils.nullishCoalescing<Types.Account>(from, _acceptAccount({owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount()}));
    let acceptedSpender = Utils.nullishCoalescing<Types.Account>(spender, _acceptAccount({owner = NULL_PRINCIPAL; subaccount = ?_getDefaultSubaccount()}));

    let transaction: Types.Transaction = switch kind {
      case (#mint) {
        {
          kind = "mint";
          timestamp = timestamp;
          mint = ?{
            to = acceptedTo;
            token_ids = Utils.nullishCoalescing<[Types.TokenId]>(tokenIds, []);
          };
          icrc7_transfer = null;
          icrc7_approve = null;
          upgrade = null;
        };
      };
      case (#upgrade) {
        {
          kind           = "upgrade";
          timestamp      = timestamp;
          mint           = null;
          icrc7_transfer = null;
          icrc7_approve  = null;
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
            token_ids = Utils.nullishCoalescing<[Types.TokenId]>(tokenIds, []);
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
          if (Utils.compareAccounts(acceptedFrom, acceptedTo) != #equal) {
            _addTransactionIdToAccount(transactionId, acceptedFrom);
          }
        };
        if (spender != null) {
          if (Utils.compareAccounts(acceptedSpender, acceptedTo) != #equal and Utils.compareAccounts(acceptedSpender, acceptedFrom) != #equal) {
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

  private func _addTransactionIdToAccount(transactionId: Types.TransactionId, account: Types.Account) {
    let accountText: Text = Utils.accountToText(_acceptAccount(account));
    let accountTransactions: [Types.TransactionId] = Utils.nullishCoalescing<[Types.TransactionId]>(Trie.get(transactionsByAccount, _keyFromText accountText, Text.equal), []);
    transactionsByAccount := Trie.put(transactionsByAccount, _keyFromText accountText, Text.equal, Utils.pushIntoArray<Types.TransactionId>(transactionId, accountTransactions)).0;
  };

  private func _incrementTransactionIndex() {
    transactionSequentialIndex := transactionSequentialIndex + 1;
  };



  public shared(msg) func upgradeNFT(upgradeArgs: Types.UpgradeArgs) : async Types.UpgradeReceipt {
    /// Validate caller
   if(Principal.notEqual(msg.caller, _cosmicraftsPrincipal)) {
   return #Err(#Unauthorized);
   };

    // assert(msg.caller == Principal.fromText("woimf-oyaaa-aaaan-qegia-cai"));
    
    /// Validate the owner?
    // if (Principal.notEqual(upgradeArgs.from.owner, owner.owner)) {
    //   return #Err(#Unauthorized);
    // };

    //cannot mint to zero principal
    if (Principal.equal(upgradeArgs.from.owner, NULL_PRINCIPAL)) {
      return #Err(#InvalidRecipient);
    };

    //cannot upgrade an new token id
    let alreadyExists = _exists(upgradeArgs.token_id);
    if (alreadyExists == false) {
      return #Err(#DoesntExistTokenId);
    };

    let now = Nat64.fromIntWrap(Time.now());

    //create the new token
    let upgradedToken: Types.TokenMetadata = {
      tokenId = upgradeArgs.token_id;
      owner = upgradeArgs.from;
      metadata = upgradeArgs.metadata;
    };

    //update the token metadata
    let tokenId : Types.TokenId = upgradeArgs.token_id;
    tokens := Trie.put(tokens, _keyFromTokenId tokenId, Nat.equal, upgradedToken).0;

    _addTokenToOwners(upgradeArgs.from, upgradeArgs.token_id);

    let _transaction: Types.Transaction = _addTransaction(#upgrade, now, ?[upgradeArgs.token_id], ?upgradeArgs.from, null, null, null, null, null);
    return #Ok(upgradeArgs.token_id);
  };

  // Self-query function to get all token IDs with their respective metadata for the caller
  public query ({ caller }) func getNFTs() : async [(Types.TokenId, Types.TokenMetadata)] {
      let entries = Iter.toArray(Trie.iter(tokens));
      
      // Initialize a buffer with an estimated size based on the number of entries
      let resultBuffer = Buffer.Buffer<(Types.TokenId, Types.TokenMetadata)>(entries.size());
      
      for (entry in entries.vals()) {
          let key = entry.0;
          let value = entry.1;
          if (value.owner.owner == caller) {
              resultBuffer.add((key, value));
          };
      };
      
      // Convert the buffer to an array before returning
      return Buffer.toArray(resultBuffer);
  };


  // Stable map to store the principal IDs of callers who have minted a deck
  stable var _mintedCallers: [(Principal, Bool)] = [];

  var mintedCallersMap: HashMap.HashMap<Principal, Bool> = HashMap.fromIter(_mintedCallers.vals(), 0, Principal.equal, Principal.hash);


public shared({ caller }) func mintDeck(): async (Bool, Text, [Types.TokenId]) {
    // Check if the caller has already minted a deck
    if (mintedCallersMap.get(caller) != null) {
        return (false, "Deck mint failed: Caller has already minted a deck", []);
    };

    let units = Utils.initDeck();

    var _deck = Buffer.Buffer<Types.MintArgs>(8);
    var uuids = Buffer.Buffer<Types.TokenId>(8);

    // Generate the initial UUID
    let initialUUID = await Utils.generateUUID64();

    for (i in Iter.range(0, 7)) {
        let (name, damage, hp, rarity) = units[i];
        // Increment the UUID for each NFT
        let uuid = initialUUID + i;
        let generalMetadata: Types.GeneralMetadata = {
            category = ?#unit(#spaceship(null));
            rarity = ?rarity;
            faction = ?#Cosmicon;
            id = uuid;
            name = name;
            description = name # " NFT";
            image = "url_to_image";
        };
        let spaceshipMetadata: Types.SpaceshipMetadata = {
            general = generalMetadata;
            basic = ?{
                level = 1;
                health = hp;
                damage = damage;
            };
            skills = null; // Set to null for now, can be updated later
            skins = null;  // Set to null for now, can be updated later
            soul = null;   // Set to null for now, can be updated later
        };
        let metadata: Types.Metadata = {
            general = spaceshipMetadata.general;
            basic = spaceshipMetadata.basic;
            skills = spaceshipMetadata.skills;
            skins = spaceshipMetadata.skins;
            soul = spaceshipMetadata.soul;
        };
        let _mintArgs: Types.MintArgs = {
            to = { owner = caller; subaccount = null };
            token_id = uuid;
            metadata = metadata; // Directly use the new NFTMetadata type
        };
        _deck.add(_mintArgs);
        uuids.add(uuid); // Collect the UUIDs
    };

    var lastTokenMinted: Nat = 0;
    let now = Nat64.fromIntWrap(Time.now());
    let acceptedTo: Types.Account = _acceptAccount({ owner = caller; subaccount = null });
    var _deckTokens: [Types.TokenId] = [];

    for (mintArgs in Buffer.toArray(_deck).vals()) {
        let tokenId: Types.TokenId = mintArgs.token_id;
        let acceptedTo: Types.Account = _acceptAccount(mintArgs.to);
        
        // Check on supply cap overflow
        if (supplyCap != null) {
            let _supplyCap: Nat = Utils.nullishCoalescing<Nat>(supplyCap, 0);
            if (totalSupply + 1 > _supplyCap) {
                return (false, "Deck mint failed: SupplyCapOverflow", []);
            };
        };
        // Cannot mint to zero principal
        if (Principal.equal(acceptedTo.owner, NULL_PRINCIPAL)) {
            return (false, "Deck mint failed: InvalidRecipient", []);
        };
        // Cannot mint an existing token id
        if (_exists(tokenId)) {
            return (false, "Deck mint failed: Token ID already exists", []);
        };
        // Create the new token
        let newToken: Types.TokenMetadata = {
            tokenId = mintArgs.token_id;
            owner = acceptedTo;
            metadata = mintArgs.metadata;
        };
        // Update the token metadata
        tokens := Trie.put(tokens, _keyFromTokenId(tokenId), Nat.equal, newToken).0;
        _addTokenToOwners(acceptedTo, mintArgs.token_id);
        _incrementBalance(acceptedTo);
        _incrementTotalSupply(1);
        _deckTokens := Utils.pushIntoArray<Types.TokenId>(tokenId, _deckTokens);
        lastTokenMinted := tokenId;
    };

    let _transaction: Types.Transaction = _addTransaction(#mint, now, ?_deckTokens, ?acceptedTo, null, null, null, null, null);
    transactionSequentialIndex += 1;

    // Record the caller's principal ID as having minted a deck
    mintedCallersMap.put(caller, true);

    return (true, "Deck minted. # NFTs: " # Nat.toText(_deckTokens.size()), _deckTokens);
};


};
