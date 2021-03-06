import React, { useState } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  Box,
  Button,
  GU,
  Header,
  Main,
  SyncIndicator,
  Text,
  textStyle,
  TextInput
} from '@aragon/ui'
import styled from 'styled-components'
import {fromDecimals, toDecimals} from './utils'

function App() {
  const { api, appState } = useAragonApi()
  const {
    isSyncing,
    sctBalance,
    sctTokenWrapperBalance,
    userStablecoinBalance,
    appStablecoinBalance,
    sctAddress,
    stablecoinAddress,
    stablecoinClaimable,
    rewardRate
  } = appState

  const [stakeAmount, setStakeAmount] = useState(0)
  const [withdrawAmount, setWithdrawAmount] = useState(0)
  const [rewardAmount, setRewardAmount] = useState(0)

  const stake = () => {
    const stakeAmountWithDecimals = toDecimals(stakeAmount, 18)
    api.stake(stakeAmountWithDecimals, {token: { address: sctAddress, value: stakeAmountWithDecimals }, gas: 500000 }).toPromise()
  }

  return (
    <Main>
      {isSyncing && <SyncIndicator />}
      <Header
        primary="Stablecoin Rewards"
        secondary={
          <Text
            css={`${textStyle('title2')}`}
          />
        }
      />

      <Box
        css={`
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          ${textStyle('title3')};
        `}
      >

        SCT Balance: {fromDecimals(sctBalance ? sctBalance : "", 18)}
        <br/>
        SCT Staked: {fromDecimals(sctTokenWrapperBalance ? sctTokenWrapperBalance : "", 18)}

        <Buttons>
          <div>
            <TextInput
              value={stakeAmount}
              onChange={event => {setStakeAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Stake"
              onClick={stake}
            />
          </div>

          <div>
            <TextInput
              value={withdrawAmount}
              onChange={event => {setWithdrawAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Withdraw"
              onClick={() => {api.withdraw(toDecimals(withdrawAmount, 18)).toPromise()}}
            />
          </div>
        </Buttons>

        User Stablecoin Balance: {fromDecimals(userStablecoinBalance ? userStablecoinBalance : "", 18)}
        <br/>
        Stablecoin Claimable: {fromDecimals(stablecoinClaimable ? stablecoinClaimable : "", 18)}
        <br/>

        <Button
          css={`margin-top: 20px;
                margin-bottom: 30px;`}
          label="Claim Reward"
          onClick={() => api.getReward().toPromise()}
        />
        <br/>

        App Stablecoin Balance: {fromDecimals(appStablecoinBalance ? appStablecoinBalance : "", 18)}
        <br/>
        Total Reward Rate (per second): {fromDecimals(rewardRate ? rewardRate : "", 18)}

        <div css={`margin-top: 20px`}>
          <TextInput
            value={rewardAmount}
            onChange={event => {setRewardAmount(event.target.value)}}
          />

          <Button
            css={`margin-left: 20px`}
            label="Distribute Reward"
            onClick={() => api.notifyRewardAmount(toDecimals(rewardAmount, 18)).toPromise()}
          />
        </div>

      </Box>
    </Main>
  )
}

const Buttons = styled.div`
  display: grid;
  grid-auto-flow: row;
  grid-gap: 20px;
  margin-top: 20px;
  margin-bottom: 30px;
`

export default App
