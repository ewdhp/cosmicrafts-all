import { defineStore } from 'pinia';
import useCanisterStore from '@/stores/canister.js';
import md5 from 'md5'; // Assuming you have an md5 library installed

export const useTopPlayersStore = defineStore(
  'topPlayers', {

  state: () => ({
    loading: true,
    loaded: false,
    topREF: [],
    topELO: [],
    topNFT: [],
    topACH: [],
    topLEV: [],
    dataHash: '',
    canister: null,
  }),

  actions: {

    async setup() {
      if (!this.canister) {
        const canisterStore = useCanisterStore();
        this.canister = await canisterStore.get('cosmicrafts');
      }
    },

    async loadStore() {
      this.loading = true;
      if (!this.loaded) {
        await this.setup();
        await this.fetchAllTopData();
        this.loaded = true;
        this.updateDataHash();
      }
      this.loading = false;
    },

    async fetchAllTopData() {
      const topData = await Promise.all([
        this.canister.getTopReferrals(0),
        this.canister.getTopELO(0),
        this.canister.getTopNFT(0),
        this.canister.getTopAchievements(0),
        this.canister.getTopLevel(0),
      ]);
      [
        this.topREF, 
        this.topELO, 
        this.topNFT, 
        this.topACH, 
        this.topLEV
      ] = topData;
    },

    updateDataHash() {
      const data = [
        ...this.topREF,
        ...this.topELO,
        ...this.topNFT,
        ...this.topACH,
        ...this.topLEV,
      ];
      const dataString = JSON.stringify(data, 
        (key, value) =>
        typeof value === 'bigint' ? 
        value.toString() : value
      );
      this.dataHash = md5(dataString);
    },

    async reloadDataIfChanged() {
      await this.setup();
      const newTopData = await Promise.all([
        this.canister.getTopReferrals(0),
        this.canister.getTopELO(0),
        this.canister.getTopNFT(0),
        this.canister.getTopAchievements(0),
        this.canister.getTopLevel(0),
      ]);
      const newData = [
        ...newTopData[0],
        ...newTopData[1],
        ...newTopData[2],
        ...newTopData[3],
        ...newTopData[4],
      ];
      const newDataString = JSON.stringify(
        newData, (key, value) =>
        typeof value === 'bigint' ? 
        value.toString() : value
      );
      const newHash = md5(newDataString);
      if (newHash !== this.dataHash) {
        [          
          this.topREF, 
          this.topELO, 
          this.topNFT, 
          this.topACH, 
          this.topLEV,
        ] = newTopData;
        this.updateDataHash();
      }
    },
  },
});